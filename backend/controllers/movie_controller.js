const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Obtiene el catalogo desde Neon. La metadata TMDB debe guardarse al importar
 * o actualizar contenido, no durante cada lectura del catalogo.
 */
exports.getMovies = async (req, res) => {
  const { type } = req.query;
  const requestedLimit = parseInt(req.query.limit, 10);
  const limit = Number.isInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 500)
    : 260;

  const contentInclude = {
    seasons: {
      include: {
        episodes: {
          orderBy: {
            episodeNumber: 'asc',
          },
        },
      },
      orderBy: {
        seasonNumber: 'asc',
      },
    },
  };

  const sortForCatalog = (items) => items.sort((a, b) => {
    const aHasImage = Boolean(a.imageUrl || a.backdropUrl);
    const bHasImage = Boolean(b.imageUrl || b.backdropUrl);
    if (aHasImage !== bHasImage) return aHasImage ? -1 : 1;
    return (b.rating || 0) - (a.rating || 0);
  });

  try {
    if (type) {
      const normalizedType = type.toLowerCase().trim().replace('s', '');
      const contents = await prisma.content.findMany({
        where: {
          type: {
            contains: normalizedType,
            mode: 'insensitive',
          },
        },
        include: contentInclude,
        orderBy: [{ rating: 'desc' }, { updatedAt: 'desc' }],
        take: limit,
      });

      return res.json(sortForCatalog(contents));
    }

    const [movies, series] = await Promise.all([
      prisma.content.findMany({
        where: { type: { contains: 'movie', mode: 'insensitive' } },
        include: contentInclude,
        orderBy: [{ rating: 'desc' }, { updatedAt: 'desc' }],
        take: limit,
      }),
      prisma.content.findMany({
        where: {
          OR: [
            { type: { contains: 'tv', mode: 'insensitive' } },
            { type: { contains: 'serie', mode: 'insensitive' } },
          ],
        },
        include: contentInclude,
        orderBy: [{ rating: 'desc' }, { updatedAt: 'desc' }],
        take: limit,
      }),
    ]);

    res.json([
      ...sortForCatalog(movies),
      ...sortForCatalog(series),
    ]);
  } catch (error) {
    console.error('Error critico en GET /api/movies:', error);
    res.status(500).json({
      error: 'Error interno al cargar el catalogo',
      details: error.message,
    });
  }
};

/**
 * Proxy para el reproductor de video para evitar bloqueos de CORS.
 */
exports.proxyStream = async (req, res) => {
  const targetUrl = req.query.url;
  if (!targetUrl) return res.status(400).send('URL de streaming requerida');

  try {
    const response = await axios.get(targetUrl, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        Referer: new URL(targetUrl).origin,
        Origin: new URL(targetUrl).origin,
      },
      timeout: 15000,
    });

    res.set('Content-Type', 'text/html');
    let html = response.data;
    const origin = new URL(targetUrl).origin;

    html = html.replace('<head>', `<head><base href="${origin}/">`);

    res.send(html);
  } catch (error) {
    console.error('Error en Proxy Stream:', error.message);
    res.status(200).send(`
            <body style="background:#000;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;">
                <div style="text-align:center;">
                    <p style="font-size: 1.2rem;">El servidor de video no esta disponible en este momento.</p>
                    <button onclick="window.location.reload()" style="background:#E50914;color:white;border:none;padding:12px 24px;border-radius:4px;cursor:pointer;font-weight:bold;margin-top:10px;">REINTENTAR</button>
                </div>
            </body>
        `);
  }
};
