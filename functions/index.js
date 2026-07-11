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

const REGION = 'us-central1';

// Secrets (set once, never committed):
//   firebase functions:secrets:set NARAROUTER_API_KEY
//   firebase functions:secrets:set BREVO_API_KEY
const NARAROUTER_API_KEY = defineSecret('NARAROUTER_API_KEY');
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

exports.nararouter = onRequest(
  {
    region: REGION,
    secrets: [NARAROUTER_API_KEY],
    cors: true,
    memory: '256MiB',
    timeoutSeconds: 120,
    maxInstances: 5,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: { message: 'Method not allowed' } });
      return;
    }
    try {
      const upstream = await fetch(
        'https://router.bynara.id/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${NARAROUTER_API_KEY.value()}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(req.body),
        },
      );
      const text = await upstream.text();
      res.status(upstream.status);
      res.setHeader('Content-Type', 'application/json');
      res.send(text);
    } catch (error) {
      logger.error('NaraRouter proxy failed', error);
      res.status(502).json({
        error: { message: `Proxy request failed: ${error.message}` },
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
        mustChangePassword: true,
        resetRequested: false,
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
        s.uid === uid ? { ...s, mustChangePassword: true, resetRequested: false } : s,
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
        s.uid === uid ? { ...s, mustChangePassword: false } : s,
      );
      tx.update(groupRef, { students, updatedAt: FieldValue.serverTimestamp() });
    });
    return { ok: true };
  },
);
