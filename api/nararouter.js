// Vercel serverless function: proxies Defense Practice's AI calls to NaraRouter.
// Runs server-side, so the API key never reaches the browser and the request
// isn't subject to CORS (NaraRouter's own API has no CORS headers by design -
// see https://router.bynara.id/docs, which says the key must stay server-side).
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: { message: 'Method not allowed' } });
    return;
  }

  const apiKey = process.env.NARAROUTER_API_KEY;
  if (!apiKey) {
    res.status(500).json({
      error: { message: 'NARAROUTER_API_KEY is not configured on the server.' },
    });
    return;
  }

  try {
    const upstream = await fetch('https://router.bynara.id/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(req.body),
    });

    const text = await upstream.text();
    res.status(upstream.status);
    res.setHeader('Content-Type', 'application/json');
    res.send(text);
  } catch (error) {
    res.status(502).json({ error: { message: `Proxy request failed: ${error.message}` } });
  }
};
