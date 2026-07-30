module.exports = async (req, res) => {
  const url = req.query.url;

  if (!url) {
    res.status(400).json({ error: 'Missing url parameter' });
    return;
  }

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Umbra-MangaHub/1.0',
        Referer: 'https://mangadex.org/',
      },
    });

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Content-Type',
      response.headers.get('content-type') || 'image/jpeg',
    );
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.status(response.status).send(buffer);
  } catch (error) {
    res.status(502).json({ error: 'Image proxy failed', message: error.message });
  }
};