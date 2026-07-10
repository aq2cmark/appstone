// AppStone Cloud Functions.
//
// Phase 1 lives here: the NaraRouter AI proxy, moved off Vercel so the whole
// backend can live in one place (Firebase) regardless of where the Flutter app
// is hosted (Vercel now, Hostinger later). The NaraRouter API key is stored as
// a Firebase secret and attached server-side, so it never ships in the app.
//
// Cost safety: every function sets maxInstances + small memory + a timeout, so
// a bug or abuse can never scale up into a surprise bill. Pair this with a $1
// budget alert in Google Cloud Billing.

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

// Set once (never committed, never in the app):
//   firebase functions:secrets:set NARAROUTER_API_KEY
const NARAROUTER_API_KEY = defineSecret('NARAROUTER_API_KEY');

// Proxies the app's AI calls to NaraRouter with the key attached, exactly like
// the old Vercel /api/nararouter function. `cors: true` lets the app call this
// from a different domain (e.g. a Hostinger-hosted build).
exports.nararouter = onRequest(
  {
    region: 'us-central1',
    secrets: [NARAROUTER_API_KEY],
    cors: true,
    memory: '256MiB',
    timeoutSeconds: 120,
    // Hard ceiling on concurrent instances - the main guard against a runaway
    // bill. Raise later only if real traffic needs it.
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
