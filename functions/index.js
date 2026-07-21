// AppStone Cloud Functions - the app's secure "back room".
//
// Everything privileged lives here, never in the app:
//   • nararouter              - proxies AI calls to NaraRouter (Phase 1)
//   • createStudent           - makes a real Firebase Auth login for a student
//   • resetStudentPassword    - admin sets a new temp password for a student
//   • deleteStudent           - removes a student's login + records
//   • sendPasswordResetEmail  - self-serve "forgot password" via Brevo email
//   • inviteAdmin             - creates an admin login + emails a setup link
//
// DATA MODEL (students):
//   • The student's REAL email is their Firebase Auth email (they log in with
//     it, or with their Student ID which we translate to it).
//   • Passwords live in Firebase Auth only - never stored in Firestore.
//   • Group docs keep the embedded student record (name, email, studentId, uid,
//     mustChangePassword) for the admin dashboard - just without any password.
//   • Two small lookup collections make login cheap and ID-based login work:
//       studentIndex/{uid}          -> { studentId, groupId, email }
//       studentIdToEmail/{STUxxx}   -> { email, uid }
//
// COST SAFETY: every function caps maxInstances so nothing can scale into a
// surprise bill. Pair with a $1 budget alert in Google Cloud Billing.

const crypto = require('crypto');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

// Firestore lives in asia-east2, so the functions do too: the admin actions each
// make several sequential reads/writes, and from us-central1 every one of them
// crossed the Pacific (~180ms each, ~1s of round trips per add/delete). In-region
// they're ~1ms. It's also ~40ms from users in PH instead of ~200ms.
//
// Keep this in step with the client: the region is compile-time there (the
// callable region in functions_service.dart and the nararouter URL in
// ai_endpoint.dart), so a build ships pinned to whatever this says. Moving
// regions means deploying to both, rebuilding the web, and only then dropping
// the old one - otherwise the live bundle calls a region that no longer exists.
const REGION = 'asia-east2';

// Groq refuses calls from asia-east2 (Hong Kong) at its Cloudflare edge with a
// bare 403 Forbidden - a geographic block, unrelated to the API key. So the
// proxy, which lives in REGION next to Firestore, can't reach Groq directly.
// A second small function (exports.groqRelay) runs HERE instead - a region Groq
// permits - and the proxy forwards its Groq-bound calls to it. NaraRouter has no
// such block, so it's still called directly from REGION.
const GROQ_RELAY_REGION = 'us-central1';
const GROQ_RELAY_URL =
  'https://us-central1-appstone-db.cloudfunctions.net/groqRelay';

// Max AI sessions per user PER FEATURE per calendar day (UTC). Each module
// (title generator, paper checker, AI workflow, defense practice) gets its own
// allowance of this many. One session = one use; a whole defense-practice run
// (many calls) counts as a single session via a shared X-AI-Session id.
const DAILY_AI_LIMIT = 5;

// Secrets (set once, never committed):
//   firebase functions:secrets:set NARAROUTER_API_KEY
//   firebase functions:secrets:set GROQ_API_KEY
//   firebase functions:secrets:set GROQ_RELAY_SECRET
//   firebase functions:secrets:set BREVO_API_KEY
const NARAROUTER_API_KEY = defineSecret('NARAROUTER_API_KEY');
const GROQ_API_KEY = defineSecret('GROQ_API_KEY');
// Shared secret gating the internal proxy -> relay hop. The relay is a public
// HTTPS function (as the proxy is), so this is what stops anyone else invoking
// it and spending our Groq quota. One secret, referenced by both functions, so
// they always see the same value.
const GROQ_RELAY_SECRET = defineSecret('GROQ_RELAY_SECRET');
const BREVO_API_KEY = defineSecret('BREVO_API_KEY');

// Non-secret config, set in functions/.env (BREVO_SENDER_EMAIL must be a sender
// you verified inside Brevo, or emails will bounce):
//   BREVO_SENDER_EMAIL=you@yourschool.edu
const BREVO_SENDER_EMAIL = defineString('BREVO_SENDER_EMAIL');
const BREVO_SENDER_NAME = defineString('BREVO_SENDER_NAME', { default: 'Appstone' });

const FieldValue = admin.firestore.FieldValue;
const db = () => admin.firestore();

// ---- helpers ---------------------------------------------------------------

// Same style of admin-issued temp password the app used before: `temp` + 6
// unambiguous chars, but now generated with a cryptographic RNG.
function genTempPassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < 6; i++) out += chars[crypto.randomInt(chars.length)];
  return 'temp' + out;
}

// Verifies the caller is a signed-in, active admin (and optionally an owner),
// by checking their `admins` doc. This is what makes these functions safe to
// expose - the powers live server-side, gated on a real admin identity.
async function assertAuthedAdmin(request, { ownerOnly = false } = {}) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in as an admin first.');
  }
  const email = (request.auth.token.email || '').toLowerCase();
  if (!email) {
    throw new HttpsError('permission-denied', 'Your account has no email.');
  }
  const snap = await db().collection('admins').doc(email).get();
  const data = snap.data();
  if (!snap.exists || data.active !== true) {
    throw new HttpsError('permission-denied', 'You are not an active admin.');
  }
  if (ownerOnly && data.role !== 'owner') {
    throw new HttpsError('permission-denied', 'Only an owner can do this.');
  }
  return { email, role: data.role };
}

// Sends one transactional email through Brevo (the reliable post office). The
// API key stays server-side; the sender must be a verified Brevo sender.
async function sendBrevoEmail({ to, toName, subject, htmlContent }) {
  const resp = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': BREVO_API_KEY.value(),
      'content-type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { email: BREVO_SENDER_EMAIL.value(), name: BREVO_SENDER_NAME.value() },
      to: [{ email: to, name: toName || to }],
      subject,
      htmlContent,
    }),
  });
  if (!resp.ok) {
    logger.error('Brevo send failed', resp.status, await resp.text());
    throw new HttpsError('internal', 'Could not send the email. Try again later.');
  }
}

// Best-effort audit entry (mirrors the app's audit_logs). Never blocks the
// action it records.
async function writeAudit(actor, action, description) {
  try {
    await db().collection('audit_logs').add({
      action,
      description,
      actorEmail: actor.email || 'unknown',
      actorUid: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn('audit write failed', e);
  }
}

// ---- Phase 1: NaraRouter AI proxy ------------------------------------------

// The real Groq endpoints. Reached ONLY from the relay (exports.groqRelay),
// which runs in a region Groq permits - the proxy itself can't call these from
// asia-east2 (see GROQ_RELAY_REGION). Both are OpenAI-compatible, so the app's
// request body works unchanged.
const GROQ_UPSTREAMS = {
  groq: {
    url: 'https://api.groq.com/openai/v1/chat/completions',
    apiKey: () => GROQ_API_KEY.value(),
  },
  // Whisper. A different endpoint on the same provider, and the only one that
  // takes audio rather than chat messages.
  groqAudio: {
    url: 'https://api.groq.com/openai/v1/audio/transcriptions',
    apiKey: () => GROQ_API_KEY.value(),
    audio: true,
  },
};

// Where a feature's AI calls go, from the PROXY's point of view. An entry with a
// `url` is called directly; one with a `relayTarget` is sent through the US relay
// instead, because Groq refuses calls from the proxy's own region.
//
// The title generator and voice transcription run on Groq: its free tier allows
// 30 requests/minute against NaraRouter's 10, so keeping the two lightest, most
// bursted features there buys NaraRouter headroom for the heavier ones. Anything
// not listed in FEATURE_UPSTREAM stays on NaraRouter, which is called directly.
const UPSTREAMS = {
  nararouter: {
    url: 'https://router.bynara.id/v1/chat/completions',
    apiKey: () => NARAROUTER_API_KEY.value(),
  },
  groq: { relayTarget: 'groq' },
  groqAudio: { relayTarget: 'groqAudio' },
};

const FEATURE_UPSTREAM = {
  'title-generator': 'groq',
  'speech-to-text': 'groqAudio',
};

const upstreamFor = (feature) =>
  UPSTREAMS[FEATURE_UPSTREAM[feature] || 'nararouter'];

// Both providers cap requests per minute ACROSS the whole app (not per user) -
// 10/min on NaraRouter, 30/min on Groq - so a handful of students acting in the
// same minute can trip it. It's a rolling window though, so a burst clears in
// seconds, which makes a 429 worth waiting out rather than surfacing as an error.
//
// The retry lives HERE rather than in the app on purpose: retrying server-side
// reuses the same X-AI-Session id, so a rate-limited call never costs a student
// one of their daily uses. A client-side retry would mint a fresh id and burn
// another one off the DAILY_AI_LIMIT allowance.
const RATE_LIMIT_BACKOFF_MS = [3000, 6000, 12000];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// How long to wait before retrying a 429. Prefers upstream's Retry-After (given
// either as seconds or an HTTP date) and otherwise falls back to our backoff
// schedule. Jitter keeps simultaneous callers from retrying in lockstep and
// re-colliding. Capped so the total wait stays well inside timeoutSeconds.
function retryDelayMs(response, attempt) {
  const retryAfter = response.headers.get('retry-after');
  if (retryAfter) {
    const seconds = Number(retryAfter);
    const ms = Number.isFinite(seconds)
      ? seconds * 1000
      : Date.parse(retryAfter) - Date.now();
    if (ms > 0) return Math.min(ms, 20000);
  }
  return RATE_LIMIT_BACKOFF_MS[attempt] + Math.floor(Math.random() * 1000);
}

// Whisper wants multipart/form-data, but this proxy - and the app's auth, CORS
// and daily-limit handling around it - all speak JSON. So the app posts the
// recording as base64 and the form gets rebuilt here, which keeps audio on the
// same signed-in, rate-limited path as every other AI call instead of needing a
// second endpoint with its own copy of that logic.
//
// Rebuilt per attempt on purpose: fetch consumes the body, so a retry can't
// reuse the same FormData.
function audioForm(body) {
  const bytes = Buffer.from(String(body.audio || ''), 'base64');
  const form = new FormData();
  form.append(
    'file',
    new Blob([bytes], { type: body.mimeType || 'audio/webm' }),
    body.filename || 'answer.webm',
  );
  form.append('model', body.model || 'whisper-large-v3');
  form.append('response_format', 'json');
  // Pinning the language stops Whisper guessing from the first few words and
  // occasionally deciding a Taglish answer should be translated instead of
  // transcribed. Students answer in English.
  form.append('language', body.language || 'en');
  return form;
}

// One AI call to the given upstream, waiting out per-minute rate limits.
// Returns the final response - still a 429 if every retry was rate-limited too.
async function callUpstream(upstream, body) {
  for (let attempt = 0; ; attempt++) {
    const isAudio = upstream.audio === true;
    const response = await fetch(upstream.url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${upstream.apiKey()}`,
        // fetch writes multipart's Content-Type itself, boundary included -
        // setting it by hand would drop the boundary and break the upload.
        ...(isAudio ? {} : { 'Content-Type': 'application/json' }),
      },
      body: isAudio ? audioForm(body) : JSON.stringify(body),
    });
    if (response.status !== 429 || attempt >= RATE_LIMIT_BACKOFF_MS.length) {
      return response;
    }
    const delay = retryDelayMs(response, attempt);
    logger.info('AI upstream rate-limited; backing off', {
      url: upstream.url,
      attempt,
      delay,
    });
    await sleep(delay);
  }
}

// Groq-bound features can't call Groq from here (it 403s this region), so they
// post to the relay (exports.groqRelay), which runs where Groq is allowed and
// hands the response straight back. The relay returns Groq's own status and body
// verbatim, so to the caller this is indistinguishable from a direct upstream
// response - the 429/refund/forward handling below needs no special case. One
// POST, no retry: the relay owns the rate-limit backoff against Groq.
async function callRelay(relayTarget, body) {
  return fetch(GROQ_RELAY_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Relay-Secret': GROQ_RELAY_SECRET.value(),
    },
    body: JSON.stringify({ target: relayTarget, body }),
  });
}

// Hands back a session this call reserved but never got to use, because the AI
// call ultimately failed. Without it a student would silently lose one of their
// DAILY_AI_LIMIT uses for a request that returned nothing. Only ever called for
// a session THIS request added, so an in-progress defense run is never touched.
async function refundSession(usageRef, feature, sessionId, today) {
  try {
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(usageRef);
      const data = snap.data();
      if (!data || data.date !== today) return; // day rolled over; nothing to undo
      const features = data.features || {};
      const sessions = features[feature] || [];
      const at = sessions.indexOf(sessionId);
      if (at === -1) return;
      sessions.splice(at, 1);
      features[feature] = sessions;
      tx.set(usageRef, {
        date: today,
        features,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    logger.warn('session refund failed', e);
  }
}

exports.nararouter = onRequest(
  {
    region: REGION,
    // GROQ_API_KEY lives on the relay now, not here - this function only needs
    // the NaraRouter key (direct calls) and the relay secret (Groq calls).
    secrets: [NARAROUTER_API_KEY, GROQ_RELAY_SECRET],
    cors: true,
    memory: '256MiB',
    timeoutSeconds: 120,
    // Locked to signed-in users below, so this can scale for real traffic
    // without a random script being able to burn AI tokens.
    maxInstances: 100,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: { message: 'Method not allowed' } });
      return;
    }
    // Require a valid Firebase login - only signed-in users of the app may use
    // the proxy. A script that merely finds the URL has no token and is refused.
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.substring(7) : '';
    if (!token) {
      res.status(401).json({ error: { message: 'Sign in required to use AI features.' } });
      return;
    }
    let uid;
    try {
      uid = (await admin.auth().verifyIdToken(token)).uid;
    } catch (_) {
      res.status(401).json({ error: { message: 'Your session expired. Sign in again.' } });
      return;
    }

    // Per-user, PER-FEATURE daily session limit. Sessions are tracked in a
    // per-user doc bucketed by feature; each feature gets its own DAILY_AI_LIMIT
    // allowance. Each distinct X-AI-Session id counts once, so a defense run
    // (many calls, one id) is a single session, and calls with an already-
    // counted id always pass (so an in-progress run finishes). Resets each UTC
    // day. The Admin SDK write bypasses rules, so no client can tamper with it.
    const feature =
      String(req.headers['x-ai-feature'] || 'other').slice(0, 40) || 'other';
    const sessionId =
      String(req.headers['x-ai-session'] || '').slice(0, 80) ||
      `call-${Date.now()}-${Math.random()}`;
    const today = new Date().toISOString().slice(0, 10);
    const usageRef = db().collection('aiUsage').doc(uid);
    // `added` tells us this request is what reserved the session, so only it may
    // hand the session back if the AI call then fails (see refundSession).
    const { allowed, added } = await db().runTransaction(async (tx) => {
      const snap = await tx.get(usageRef);
      const data = snap.data() || {};
      const features = data.date === today ? data.features || {} : {};
      const sessions = features[feature] || [];
      if (sessions.includes(sessionId)) {
        return { allowed: true, added: false }; // part of an ongoing session
      }
      if (sessions.length >= DAILY_AI_LIMIT) {
        return { allowed: false, added: false }; // this feature's cap hit
      }
      sessions.push(sessionId);
      features[feature] = sessions;
      tx.set(usageRef, {
        date: today,
        features,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { allowed: true, added: true };
    });
    if (!allowed) {
      // 'daily-limit': the student spent this feature's allowance. Distinct from
      // the 'busy' 429 below - this one genuinely means "come back tomorrow".
      res.status(429).json({
        error: {
          code: 'daily-limit',
          message: `You've reached today's limit for this feature (${DAILY_AI_LIMIT} per day). Please try again tomorrow.`,
        },
      });
      return;
    }

    try {
      // Direct call for NaraRouter; the relay hop for Groq-bound features. Both
      // return a plain fetch Response, so everything below treats them alike.
      const route = upstreamFor(feature);
      const upstream = route.relayTarget
        ? await callRelay(route.relayTarget, req.body)
        : await callUpstream(route, req.body);

      // Still rate-limited after every retry. Report it as 'busy' so the app
      // tells the student to try again shortly, instead of wrongly claiming
      // their daily allowance is gone - and give the reserved session back.
      if (upstream.status === 429) {
        logger.warn('AI upstream still rate-limited after retries', { feature });
        if (added) await refundSession(usageRef, feature, sessionId, today);
        res.status(429).json({
          error: {
            code: 'busy',
            message:
              'The AI service is busy right now. Please try again in a moment.',
          },
        });
        return;
      }

      // Any other upstream failure didn't produce a result either, so it
      // shouldn't cost a use.
      if (!upstream.ok && added) {
        await refundSession(usageRef, feature, sessionId, today);
      }

      const text = await upstream.text();

      // Surface the provider's own error. Without this the proxy forwards the
      // upstream body straight to the app and logs nothing, so a real fault -
      // a bad or expired API key, an account limit, a decommissioned model -
      // only ever shows up as an opaque status code on the client and is
      // invisible in Cloud Logging. Naming the provider makes a Groq-only
      // failure attributable at a glance. Safe to log: the body may echo the
      // request, but the API key lives solely in the Authorization header we
      // send upstream and is never part of the response.
      if (!upstream.ok) {
        logger.error('AI upstream returned an error', {
          feature,
          provider: FEATURE_UPSTREAM[feature] || 'nararouter',
          status: upstream.status,
          body: text.slice(0, 500),
        });
      }

      res.status(upstream.status);
      res.setHeader('Content-Type', 'application/json');
      res.send(text);
    } catch (error) {
      logger.error('NaraRouter proxy failed', error);
      if (added) await refundSession(usageRef, feature, sessionId, today);
      res.status(502).json({
        error: { message: `Proxy request failed: ${error.message}` },
      });
    }
  },
);

// The Groq relay. Groq blocks the proxy's region (asia-east2) at its edge, so the
// proxy can't reach Groq directly; this function runs in GROQ_RELAY_REGION - a
// region Groq permits - and exists solely to make the Groq call on the proxy's
// behalf and hand back the raw result. It does NO auth or rate-limit accounting
// of its own: the proxy already verified the user, charged the daily allowance
// and applied the per-minute backoff before forwarding. This hop is gated only
// by the shared secret, so nothing but our proxy can spend the Groq key. Not
// called by browsers, so no CORS.
exports.groqRelay = onRequest(
  {
    region: GROQ_RELAY_REGION,
    secrets: [GROQ_API_KEY, GROQ_RELAY_SECRET],
    memory: '256MiB',
    timeoutSeconds: 120,
    // Small cap: only our single proxy ever calls this, one hop per AI request.
    maxInstances: 20,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: { message: 'Method not allowed' } });
      return;
    }
    // The only thing between this public URL and our Groq quota. A wrong or
    // missing secret is refused before any Groq call is made.
    if (req.headers['x-relay-secret'] !== GROQ_RELAY_SECRET.value()) {
      res.status(403).json({ error: { message: 'Forbidden' } });
      return;
    }
    const target = GROQ_UPSTREAMS[req.body && req.body.target];
    if (!target) {
      res.status(400).json({ error: { message: 'Unknown relay target' } });
      return;
    }
    try {
      const response = await callUpstream(target, req.body.body || {});
      const text = await response.text();
      if (!response.ok) {
        logger.error('Groq relay upstream error', {
          target: req.body.target,
          status: response.status,
          body: text.slice(0, 500),
        });
      }
      res.status(response.status);
      res.setHeader(
        'Content-Type',
        response.headers.get('content-type') || 'application/json',
      );
      res.send(text);
    } catch (error) {
      logger.error('Groq relay failed', error);
      res.status(502).json({
        error: { message: `Relay request failed: ${error.message}` },
      });
    }
  },
);

// ---- Phase 2: student account management -----------------------------------

// Admin creates a student: reserves a Student ID, makes a real Auth login with
// a one-time temp password (returned to the admin to hand over), and saves the
// record + lookup indexes. Rolls back the Auth user if the save fails, so there
// are never orphaned logins.
exports.createStudent = onCall(
  { region: REGION, maxInstances: 10 },
  async (request) => {
    const actor = await assertAuthedAdmin(request);
    const name = String(request.data?.name || '').trim();
    const email = String(request.data?.email || '').trim().toLowerCase();
    const groupId = String(request.data?.groupId || '').trim();
    if (!name || !email || !email.includes('@') || !groupId) {
      throw new HttpsError(
        'invalid-argument',
        'Name, a valid email, and a group are required.',
      );
    }

    const groupRef = db().collection('groups').doc(groupId);
    const counterRef = db().collection('metadata').doc('studentCounter');

    // Reserve a Student ID and confirm the group has room, atomically.
    const studentId = await db().runTransaction(async (tx) => {
      const groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) {
        throw new HttpsError('not-found', 'That group no longer exists.');
      }
      const students = groupSnap.data().students || [];
      if (students.length >= 5) {
        throw new HttpsError('failed-precondition', 'This group already has 5 members.');
      }
      const counterSnap = await tx.get(counterRef);
      const n = (counterSnap.data() && counterSnap.data().nextNumber) || 1;
      tx.set(counterRef, { nextNumber: n + 1 }, { merge: true });
      return 'STU' + String(n).padStart(3, '0');
    });

    const tempPassword = genTempPassword();

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email,
        password: tempPassword,
        displayName: name,
      });
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'A login with this email already exists.');
      }
      throw new HttpsError('internal', 'Could not create the login: ' + e.message);
    }
    const uid = userRecord.uid;

    try {
      const record = {
        id: uid,
        name,
        email,
        studentId,
        uid,
        // The shareable temp password, kept only until the student sets their
        // own (then cleared). Their real password lives in Auth, never here.
        tempPassword,
        mustChangePassword: true,
      };
      const batch = db().batch();
      batch.update(groupRef, {
        students: FieldValue.arrayUnion(record),
        updatedAt: FieldValue.serverTimestamp(),
      });
      batch.set(db().collection('studentIndex').doc(uid), { studentId, groupId, email });
      batch.set(db().collection('studentIdToEmail').doc(studentId), { email, uid });
      await batch.commit();
    } catch (e) {
      // Undo the Auth account so a failed save can't leave an orphan login.
      await admin.auth().deleteUser(uid).catch(() => {});
      throw new HttpsError('internal', 'Could not save the student; no account was created.');
    }

    await writeAudit(actor, 'student.register', `Registered ${name} (${studentId})`);
    return { studentId, tempPassword, uid };
  },
);

// Admin resets a student to a fresh temp password (returned to the admin), and
// flags the record so the app forces a change on next login.
exports.resetStudentPassword = onCall(
  { region: REGION, maxInstances: 10 },
  async (request) => {
    const actor = await assertAuthedAdmin(request);
    const uid = String(request.data?.uid || '').trim();
    const groupId = String(request.data?.groupId || '').trim();
    if (!uid || !groupId) {
      throw new HttpsError('invalid-argument', 'uid and groupId are required.');
    }

    // Only ever act on a real STUDENT uid. Students have a studentIndex entry;
    // admins/owners do not - so this stops one admin from resetting another
    // admin's (or the owner's) password by passing their uid.
    const idxSnap = await db().collection('studentIndex').doc(uid).get();
    if (!idxSnap.exists) {
      throw new HttpsError('failed-precondition', 'That is not a student account.');
    }

    const tempPassword = genTempPassword();
    try {
      await admin.auth().updateUser(uid, { password: tempPassword });
    } catch (e) {
      throw new HttpsError('not-found', 'That student login no longer exists.');
    }

    const groupRef = db().collection('groups').doc(groupId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(groupRef);
      if (!snap.exists) return;
      const students = (snap.data().students || []).map((s) =>
        s.uid === uid
          ? { ...s, tempPassword, mustChangePassword: true }
          : s,
      );
      tx.update(groupRef, { students, updatedAt: FieldValue.serverTimestamp() });
    });

    await writeAudit(actor, 'student.resetPassword', `Reset password for student ${uid}`);
    return { tempPassword };
  },
);

// Admin deletes a student: removes the Auth login and every stored record.
exports.deleteStudent = onCall(
  { region: REGION, maxInstances: 10 },
  async (request) => {
    const actor = await assertAuthedAdmin(request);
    const uid = String(request.data?.uid || '').trim();
    const groupId = String(request.data?.groupId || '').trim();
    const studentId = String(request.data?.studentId || '').trim();
    if (!uid || !groupId) {
      throw new HttpsError('invalid-argument', 'uid and groupId are required.');
    }

    // Guard: only delete a real STUDENT (has a studentIndex entry) - never an
    // admin/owner account passed by uid.
    const idxSnap = await db().collection('studentIndex').doc(uid).get();
    if (!idxSnap.exists) {
      throw new HttpsError('failed-precondition', 'That is not a student account.');
    }

    await admin.auth().deleteUser(uid).catch(() => {}); // ignore if already gone

    const groupRef = db().collection('groups').doc(groupId);
    const snap = await groupRef.get();
    const batch = db().batch();
    if (snap.exists) {
      const students = (snap.data().students || []).filter((s) => s.uid !== uid);
      batch.update(groupRef, { students, updatedAt: FieldValue.serverTimestamp() });
    }
    batch.delete(db().collection('studentIndex').doc(uid));
    if (studentId) batch.delete(db().collection('studentIdToEmail').doc(studentId));
    await batch.commit();

    await writeAudit(actor, 'student.delete', `Deleted student ${studentId || uid}`);
    return { ok: true };
  },
);

// Self-serve "forgot password" for students AND admins. Resolves a Student ID
// or email to an account, then emails a Firebase reset link through Brevo.
// Always returns ok so it never reveals whether an account exists.
exports.sendPasswordResetEmail = onCall(
  { region: REGION, maxInstances: 10, secrets: [BREVO_API_KEY] },
  async (request) => {
    const identifier = String(request.data?.identifier || '').trim();
    if (!identifier) {
      throw new HttpsError('invalid-argument', 'Enter your Student ID or email.');
    }

    let email = identifier.toLowerCase();
    if (!identifier.includes('@')) {
      const snap = await db()
        .collection('studentIdToEmail')
        .doc(identifier.toUpperCase())
        .get();
      if (!snap.exists) return { ok: true };
      email = snap.data().email;
    }

    let link;
    try {
      link = await admin.auth().generatePasswordResetLink(email);
    } catch (e) {
      return { ok: true }; // unknown email etc. - stay generic
    }

    await sendBrevoEmail({
      to: email,
      subject: 'Reset your Appstone password',
      htmlContent:
        `<p>We received a request to reset your Appstone password.</p>` +
        `<p><a href="${link}">Click here to set a new password</a>. ` +
        `If you didn't ask for this, you can safely ignore this email.</p>`,
    });
    return { ok: true };
  },
);

// ---- Phase 2: admin invites -------------------------------------------------

// Owner invites an admin: creates their Auth login and admins record, then
// emails them a link to set their own password (proving they control the
// inbox before the account is usable).
exports.inviteAdmin = onCall(
  { region: REGION, maxInstances: 10, secrets: [BREVO_API_KEY] },
  async (request) => {
    const actor = await assertAuthedAdmin(request, { ownerOnly: true });
    const name = String(request.data?.name || '').trim();
    const email = String(request.data?.email || '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Enter a valid email address.');
    }

    const ref = db().collection('admins').doc(email);
    if ((await ref.get()).exists) {
      throw new HttpsError('already-exists', 'An admin with this email already exists.');
    }

    let uid;
    try {
      const u = await admin.auth().createUser({
        email,
        password: genTempPassword(),
        displayName: name || email,
      });
      uid = u.uid;
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        uid = (await admin.auth().getUserByEmail(email)).uid;
      } else {
        throw new HttpsError('internal', 'Could not create the admin login: ' + e.message);
      }
    }

    await ref.set({
      email,
      name: name || email,
      role: 'admin',
      active: true,
      uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const link = await admin.auth().generatePasswordResetLink(email);
    await sendBrevoEmail({
      to: email,
      toName: name,
      subject: 'You have been invited as an Appstone admin',
      htmlContent:
        `<p>Hi ${name || ''},</p>` +
        `<p>You've been invited to the Appstone admin portal. ` +
        `<a href="${link}">Click here to set your password</a>, then sign in with your email.</p>`,
    });

    await writeAudit(actor, 'admin.invite', `Invited admin ${email}`);
    return { ok: true };
  },
);

// Owner-only: request an ownership transfer. Records the pending target on the
// owner's admin doc, then emails the OWNER (via Brevo) a sign-in confirmation
// link - proving they still control the inbox before the swap. The verify +
// role swap still happen client-side after they click and confirm, so an
// email scanner opening the link can't trigger the transfer on its own.
exports.requestOwnershipTransfer = onCall(
  { region: REGION, maxInstances: 10, secrets: [BREVO_API_KEY] },
  async (request) => {
    const actor = await assertAuthedAdmin(request, { ownerOnly: true });
    const toEmail = String(request.data?.toEmail || '').trim().toLowerCase();
    const appOrigin = String(request.data?.appOrigin || '').trim();
    if (!toEmail || !appOrigin) {
      throw new HttpsError('invalid-argument', 'Target admin and app origin are required.');
    }

    const targetSnap = await db().collection('admins').doc(toEmail).get();
    if (!targetSnap.exists) {
      throw new HttpsError('not-found', 'That admin record no longer exists.');
    }
    if (targetSnap.data().active !== true) {
      throw new HttpsError('failed-precondition', 'Reactivate this admin before making them owner.');
    }

    const ownerEmail = actor.email;
    await db().collection('admins').doc(ownerEmail).update({
      pendingOwnerTransferTo: toEmail,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Same sign-in link the old flow used, but generated (not sent) here so we
    // can deliver it through Brevo. The continue URL carries the transfer
    // target so the app can show the right confirmation.
    const continueUrl = `${appOrigin}?intent=ownerTransfer&to=${encodeURIComponent(toEmail)}`;
    const link = await admin.auth().generateSignInWithEmailLink(ownerEmail, {
      url: continueUrl,
      handleCodeInApp: true,
    });

    await sendBrevoEmail({
      to: ownerEmail,
      subject: 'Confirm Appstone ownership transfer',
      htmlContent:
        `<p>You requested to transfer Appstone ownership to <b>${toEmail}</b>.</p>` +
        `<p><a href="${link}">Click here to confirm the transfer</a>. ` +
        `If you didn't request this, ignore this email and nothing changes.</p>`,
    });

    await writeAudit(actor, 'admin.transferRequest', `Requested ownership transfer to ${toEmail}`);
    return { ok: true };
  },
);

// ---- Student self-service --------------------------------------------------

// Called by a signed-in student right after they set their own password, to
// clear the "must change" flag on their record. request.auth.uid guarantees a
// student can only ever clear their own flag.
exports.finishStudentPasswordChange = onCall(
  { region: REGION, maxInstances: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in first.');
    }
    const uid = request.auth.uid;
    const groupId = String(request.data?.groupId || '').trim();
    if (!groupId) {
      throw new HttpsError('invalid-argument', 'groupId is required.');
    }

    const groupRef = db().collection('groups').doc(groupId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(groupRef);
      if (!snap.exists) return;
      const students = (snap.data().students || []).map((s) =>
        // Clear the temp password once they've set their own - it's no longer
        // valid and shouldn't linger in Firestore.
        s.uid === uid ? { ...s, mustChangePassword: false, tempPassword: '' } : s,
      );
      tx.update(groupRef, { students, updatedAt: FieldValue.serverTimestamp() });
    });
    return { ok: true };
  },
);
