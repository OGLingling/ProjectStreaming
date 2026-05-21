import axios from 'axios'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

const TMDB_API_KEY = process.env.TMDB_API_KEY || 'd8a00b94f5c00821e497b569fec9a61f'
const TMDB_BASE_URL = 'https://api.themoviedb.org/3'
const TMDB_IMAGE_BASE_URL = 'https://image.tmdb.org/t/p/original'

const seriesTmdbIds = [
  '209867', // Frieren: Beyond Journey's End
  '65942',  // Re:ZERO -Starting Life in Another World-
  '37854',  // One Piece
  '76479',  // The Boys
  '95557',  // Invincible
  '85552',  // Euphoria
  '79744',  // The Rookie
  '95479',  // JUJUTSU KAISEN
  '61374',  // Tokyo Ghoul
]

const movieTmdbIds = [
  '687163',  // Project Hail Mary
  '1226863', // The Super Mario Galaxy Movie
  '936075',  // Michael
  '980431',  // Avatar: Aang, The Last Airbender
  '1314481', // The Devil Wears Prada 2
]

type SeasonEpisodeOverride = number | {
  seasonNumber?: number
  episodeCount: number
  title?: string
}

const seriesEpisodeOverrides: Record<string, SeasonEpisodeOverride[]> = {
  '37854': [1160], // One Piece
  '65942': [25, 25, 16, 19], // Re:ZERO -Starting Life in Another World-
  '209867': [28, 10], // Frieren: Beyond Journey's End
  '79744': [20, 20, 14, 22, 22, 10, 18, 18], // The Rookie
  '85552': [8, 8, 8, { seasonNumber: 0, episodeCount: 2, title: 'Especiales' }], // Euphoria
  '61374': [12, 12, 12, 12], // Tokyo Ghoul
  '95479': [24, 23, 13], // JUJUTSU KAISEN
  '95557': [8, 8, 6, 8], // Invincible
}

const seriesSeasonTitleOverrides: Record<string, string[]> = {
  '37854': ['Episodios'], // One Piece no se muestra dividido por temporadas
}

type TmdbSeason = {
  id: number
  name?: string
  season_number: number
  episode_count?: number
}

type TmdbEpisode = {
  name?: string
  overview?: string
  episode_number: number
  still_path?: string | null
  runtime?: number | null
}

type TmdbDetails = {
  id: number
  title?: string
  name?: string
  original_name?: string
  overview?: string
  release_date?: string
  first_air_date?: string
  vote_average?: number
  poster_path?: string | null
  backdrop_path?: string | null
  genres?: Array<{ name: string }>
  videos?: { results?: Array<{ site?: string; type?: string; key?: string }> }
  seasons?: TmdbSeason[]
}

type TmdbSeasonDetails = {
  id: number
  name?: string
  season_number: number
  episodes?: TmdbEpisode[]
}

function imageUrl(path?: string | null) {
  return path ? `${TMDB_IMAGE_BASE_URL}${path}` : null
}

async function tmdbGet<T>(path: string, params: Record<string, string> = {}) {
  const response = await axios.get<T>(`${TMDB_BASE_URL}${path}`, {
    params: {
      api_key: TMDB_API_KEY,
      language: 'es-ES',
      ...params,
    },
  })

  return response.data
}

async function fetchContentDetails(tmdbId: string, type: 'movie' | 'tv') {
  return tmdbGet<TmdbDetails>(`/${type}/${tmdbId}`, {
    append_to_response: 'videos',
  })
}

async function fetchSeasonDetails(tmdbId: string, seasonNumber: number) {
  return tmdbGet<TmdbSeasonDetails>(`/tv/${tmdbId}/season/${seasonNumber}`)
}

function normalizeSeasonOverride(override: SeasonEpisodeOverride, index: number) {
  if (typeof override === 'number') {
    return {
      seasonNumber: index + 1,
      episodeCount: override,
      title: undefined,
    }
  }

  return {
    seasonNumber: override.seasonNumber ?? index + 1,
    episodeCount: override.episodeCount,
    title: override.title,
  }
}

async function buildOverriddenSeasons(tmdbId: string, seasons: TmdbSeason[], overrides: SeasonEpisodeOverride[]) {
  const seasonsForCreate = []

  for (const [seasonIndex, override] of overrides.entries()) {
    const { seasonNumber, episodeCount, title } = normalizeSeasonOverride(override, seasonIndex)
    const originalSeason = seasons.find((season) => season.season_number === seasonNumber)
    let seasonDetails: TmdbSeasonDetails | null = null

    if (originalSeason) {
      try {
        seasonDetails = await fetchSeasonDetails(tmdbId, seasonNumber)
      } catch (error) {
        console.warn(`No se pudo consultar TMDB ${tmdbId} temporada ${seasonNumber}:`, (error as Error).message)
      }
    }

    const episodes = Array.from({ length: episodeCount }, (_, episodeIndex) => {
      const episodeNumber = episodeIndex + 1
      const tmdbEpisode = seasonDetails?.episodes?.find((episode) => episode.episode_number === episodeNumber)

      return {
        episodeNumber,
        title: tmdbEpisode?.name || `Episodio ${episodeNumber}`,
        description: tmdbEpisode?.overview || null,
        stillPath: imageUrl(tmdbEpisode?.still_path),
        duration: tmdbEpisode?.runtime ? `${tmdbEpisode.runtime}m` : null,
      }
    })

    seasonsForCreate.push({
      tmdbId: seasonDetails?.id ? String(seasonDetails.id) : originalSeason?.id ? String(originalSeason.id) : `${tmdbId}-season-${seasonNumber}`,
      seasonNumber,
      title: title || seriesSeasonTitleOverrides[tmdbId]?.[seasonIndex] || seasonDetails?.name || originalSeason?.name || `Temporada ${seasonNumber}`,
      episodes: {
        create: episodes,
      },
    })
  }

  return seasonsForCreate
}

async function createMovie(tmdbId: string) {
  const data = await fetchContentDetails(tmdbId, 'movie')
  const trailer = data.videos?.results?.find(
    (video) => video.site === 'YouTube' && video.type === 'Trailer',
  ) || data.videos?.results?.find((video) => video.site === 'YouTube')

  await prisma.content.create({
    data: {
      tmdbId: String(data.id),
      title: data.title || data.name || data.original_name || 'Sin titulo',
      description: data.overview || null,
      releaseDate: data.release_date || data.first_air_date || null,
      imageUrl: imageUrl(data.poster_path),
      backdropUrl: imageUrl(data.backdrop_path),
      trailerUrl: trailer?.key ? `https://www.youtube.com/watch?v=${trailer.key}` : null,
      type: 'movie',
      category: data.genres?.map((genre) => genre.name).join(', ') || null,
      rating: data.vote_average || 0,
    },
  })
}

async function createSeries(tmdbId: string) {
  const data = await fetchContentDetails(tmdbId, 'tv')
  const seasons = data.seasons || []
  const availableSeasons = seasons.filter((season) => (season.episode_count || 0) > 0)

  let seasonsForCreate = []
  const episodeOverride = seriesEpisodeOverrides[tmdbId]

  if (episodeOverride) {
    seasonsForCreate = await buildOverriddenSeasons(tmdbId, availableSeasons, episodeOverride)
  } else {
    for (const season of availableSeasons.filter((season) => season.season_number > 0)) {
      const seasonDetails = await fetchSeasonDetails(tmdbId, season.season_number)
      const episodes = (seasonDetails.episodes || [])
        .filter((episode) => episode.episode_number > 0)
        .map((episode) => ({
          episodeNumber: episode.episode_number,
          title: episode.name || `Episodio ${episode.episode_number}`,
          description: episode.overview || null,
          stillPath: imageUrl(episode.still_path),
          duration: episode.runtime ? `${episode.runtime}m` : null,
        }))

      seasonsForCreate.push({
        tmdbId: String(seasonDetails.id || season.id),
        seasonNumber: season.season_number,
        title: seasonDetails.name || season.name || `Temporada ${season.season_number}`,
        episodes: {
          create: episodes,
        },
      })
    }
  }

  await prisma.content.create({
    data: {
      tmdbId: String(data.id),
      title: data.name || data.title || data.original_name || 'Sin titulo',
      description: data.overview || null,
      releaseDate: data.first_air_date || data.release_date || null,
      imageUrl: imageUrl(data.poster_path),
      backdropUrl: imageUrl(data.backdrop_path),
      type: 'tv',
      category: data.genres?.map((genre) => genre.name).join(', ') || null,
      rating: data.vote_average || 0,
      seasons: {
        create: seasonsForCreate,
      },
    },
  })
}

async function main() {
  console.log('--- Iniciando limpieza total ---')
  await prisma.content.deleteMany()
  console.log('Base de datos limpiada.')

  console.log('--- Insertando series desde TMDB ---')
  for (const tmdbId of seriesTmdbIds) {
    await createSeries(tmdbId)
    console.log(`Serie TMDB ${tmdbId} sincronizada.`)
  }

  console.log('--- Insertando peliculas desde TMDB ---')
  for (const tmdbId of movieTmdbIds) {
    await createMovie(tmdbId)
    console.log(`Pelicula TMDB ${tmdbId} sincronizada.`)
  }

  console.log('--- SEED FINALIZADO CON EXITO ---')
}

main()
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
