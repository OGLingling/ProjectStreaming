const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const contentInclude = {
  seasons: {
    include: {
      episodes: { orderBy: { episodeNumber: 'asc' } },
    },
    orderBy: { seasonNumber: 'asc' },
  },
};

function formatContent(content, contentId) {
  return {
    id: contentId || content?.id,
    contentId: contentId || content?.id,
    tmdb_id: content?.tmdbId,
    tmdbId: content?.tmdbId,
    title: content?.title || 'Sin titulo',
    description: content?.description,
    releaseDate: content?.releaseDate,
    image: content?.imageUrl || '',
    imageUrl: content?.imageUrl || '',
    backdropUrl: content?.backdropUrl || '',
    trailerUrl: content?.trailerUrl || '',
    rating: content?.rating || 0,
    category: content?.category,
    type: content?.type || 'movie',
    seasons: content?.seasons || [],
  };
}

const getWatchlist = async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: 'userId requerido' });

  try {
    const list = await prisma.watchlist.findMany({
      where: { userId },
      include: { content: { include: contentInclude } },
      orderBy: { createdAt: 'desc' },
    });

    res.status(200).json(
      list.map((item) => formatContent(item.content, item.contentId)),
    );
  } catch (error) {
    console.error('Error en getWatchlist:', error);
    res.status(500).json({ error: error.message });
  }
};

const toggleWatchlist = async (req, res) => {
  const { userId, contentId } = req.body;
  if (!userId || !contentId) {
    return res.status(400).json({ error: 'Datos incompletos' });
  }

  try {
    const parsedContentId = parseInt(contentId, 10);
    const existing = await prisma.watchlist.findFirst({
      where: { userId, contentId: parsedContentId },
    });

    if (existing) {
      await prisma.watchlist.delete({ where: { id: existing.id } });
      return res.status(200).json({ message: 'Eliminado' });
    }

    const newItem = await prisma.watchlist.create({
      data: { userId, contentId: parsedContentId },
      include: { content: { include: contentInclude } },
    });
    return res.status(201).json(formatContent(newItem.content, newItem.contentId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getWatchlist,
  toggleWatchlist,
};
