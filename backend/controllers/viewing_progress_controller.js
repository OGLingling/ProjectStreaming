const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const progressThresholdSeconds = 45;
const completionRatio = 0.92;

const contentInclude = {
  seasons: {
    include: {
      episodes: { orderBy: { episodeNumber: 'asc' } },
    },
    orderBy: { seasonNumber: 'asc' },
  },
};

function isCompleted(progressSeconds, durationSeconds, completed) {
  if (completed === true) return true;
  if (!durationSeconds || durationSeconds <= 0) return false;
  return progressSeconds / durationSeconds >= completionRatio;
}

function formatProgress(item) {
  const duration = item.durationSeconds || null;
  const ratio = duration
    ? Math.min(item.progressSeconds / duration, 1)
    : Math.min(item.progressSeconds / (45 * 60), 0.9);

  return {
    id: item.contentId,
    contentId: item.contentId,
    progressId: item.id,
    tmdb_id: item.content?.tmdbId,
    tmdbId: item.content?.tmdbId,
    title: item.content?.title || 'Sin titulo',
    description: item.content?.description,
    releaseDate: item.content?.releaseDate,
    image: item.content?.imageUrl || '',
    imageUrl: item.content?.imageUrl || '',
    backdropUrl: item.content?.backdropUrl || '',
    trailerUrl: item.content?.trailerUrl || '',
    rating: item.content?.rating || 0,
    category: item.content?.category,
    type: item.content?.type || 'movie',
    seasons: item.content?.seasons || [],
    seasonNumber: item.seasonNumber,
    episodeNumber: item.episodeNumber,
    progressSeconds: item.progressSeconds,
    durationSeconds: duration,
    progress: ratio,
    updatedAt: item.updatedAt,
  };
}

async function resolveContent({ contentId, tmdbId }) {
  if (contentId) {
    const content = await prisma.content.findUnique({
      where: { id: parseInt(contentId, 10) },
    });
    if (content) return content;
  }

  if (tmdbId) {
    return prisma.content.findUnique({ where: { tmdbId: String(tmdbId) } });
  }

  return null;
}

const getViewingProgress = async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: 'userId requerido' });

  try {
    const items = await prisma.viewingProgress.findMany({
      where: {
        userId,
        completed: false,
        progressSeconds: { gte: progressThresholdSeconds },
      },
      include: { content: { include: contentInclude } },
      orderBy: { updatedAt: 'desc' },
      take: 20,
    });

    res.json(items.map(formatProgress));
  } catch (error) {
    console.error('Error en getViewingProgress:', error);
    res.status(500).json({ error: error.message });
  }
};

const upsertViewingProgress = async (req, res) => {
  const {
    userId,
    contentId,
    tmdbId,
    seasonNumber = 1,
    episodeNumber = 1,
    progressSeconds = 0,
    durationSeconds,
    completed = false,
  } = req.body;

  if (!userId || (!contentId && !tmdbId)) {
    return res.status(400).json({ error: 'userId y contentId/tmdbId requeridos' });
  }

  try {
    const content = await resolveContent({ contentId, tmdbId });
    if (!content) {
      return res.status(404).json({ error: 'Contenido no encontrado' });
    }

    const normalizedSeason = Math.max(parseInt(seasonNumber, 10) || 1, 1);
    const normalizedEpisode = Math.max(parseInt(episodeNumber, 10) || 1, 1);
    const normalizedProgress = Math.max(parseInt(progressSeconds, 10) || 0, 0);
    const normalizedDuration = durationSeconds
      ? Math.max(parseInt(durationSeconds, 10) || 0, 0)
      : null;

    if (isCompleted(normalizedProgress, normalizedDuration, completed)) {
      await prisma.viewingProgress.deleteMany({
        where: {
          userId,
          contentId: content.id,
          seasonNumber: normalizedSeason,
          episodeNumber: normalizedEpisode,
        },
      });
      return res.json({ completed: true, removed: true });
    }

    if (normalizedProgress < progressThresholdSeconds) {
      return res.json({ skipped: true });
    }

    const item = await prisma.viewingProgress.upsert({
      where: {
        userId_contentId_seasonNumber_episodeNumber: {
          userId,
          contentId: content.id,
          seasonNumber: normalizedSeason,
          episodeNumber: normalizedEpisode,
        },
      },
      update: {
        progressSeconds: normalizedProgress,
        durationSeconds: normalizedDuration,
        completed: false,
      },
      create: {
        userId,
        contentId: content.id,
        seasonNumber: normalizedSeason,
        episodeNumber: normalizedEpisode,
        progressSeconds: normalizedProgress,
        durationSeconds: normalizedDuration,
      },
      include: { content: { include: contentInclude } },
    });

    res.json(formatProgress(item));
  } catch (error) {
    console.error('Error en upsertViewingProgress:', error);
    res.status(500).json({ error: error.message });
  }
};

const completeViewingProgress = async (req, res) => {
  const { userId, contentId, tmdbId, seasonNumber = 1, episodeNumber = 1 } = req.body;
  if (!userId || (!contentId && !tmdbId)) {
    return res.status(400).json({ error: 'userId y contentId/tmdbId requeridos' });
  }

  try {
    const content = await resolveContent({ contentId, tmdbId });
    if (!content) return res.status(404).json({ error: 'Contenido no encontrado' });

    await prisma.viewingProgress.deleteMany({
      where: {
        userId,
        contentId: content.id,
        seasonNumber: Math.max(parseInt(seasonNumber, 10) || 1, 1),
        episodeNumber: Math.max(parseInt(episodeNumber, 10) || 1, 1),
      },
    });

    res.json({ completed: true, removed: true });
  } catch (error) {
    console.error('Error en completeViewingProgress:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getViewingProgress,
  upsertViewingProgress,
  completeViewingProgress,
};
