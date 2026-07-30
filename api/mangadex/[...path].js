module.exports = async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).end();
    return;
  }

  const prefix = '/api/mangadex/';
  const idx = req.url.indexOf(prefix);
  const rawTail = idx !== -1 ? req.url.slice(idx + prefix.length) : '';

  const [pathPart, queryPart] = rawTail.split('?');

  let targetUrl = `https://api.mangadex.org/${pathPart}`;

  if (queryPart) {
    const params = new URLSearchParams(queryPart);

    // Strip Vercel's internal routing params — these leak into req.url
    // for bracket-based catch-all functions and aren't real API params.
    for (const key of [...params.keys()]) {
      if (key.startsWith('___') || key === 'path') {
        params.delete(key);
      }
    }

    const cleanedQuery = params.toString();
    if (cleanedQuery) {
      targetUrl += `?${cleanedQuery}`;
    }
  }

  try {
    const response = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'User-Agent': 'Umbra-MangaHub/1.0' },
    });

    const data = await response.text();

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Content-Type',
      response.headers.get('content-type') || 'application/json',
    );
    res.status(response.status).send(data);
  } catch (error) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.status(502).json({ error: 'Proxy request failed', message: error.message });
  }
};