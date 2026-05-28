import axios from 'axios'
import * as fs from 'fs'
import * as path from 'path'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

const TMDB_API_KEY = process.env.TMDB_API_KEY || 'd8a00b94f5c00821e497b569fec9a61f'
const TMDB_BASE_URL = 'https://api.themoviedb.org/3'
const TMDB_IMAGE_BASE_URL = 'https://image.tmdb.org/t/p/original'
const TMDB_DATASET_DIR = process.env.TMDB_DATASET_DIR || 'C:\\Users\\Usuario\\Desktop\\tmdb_dataset'

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

type DatasetMovie = {
  id?: string | number
  title?: string
  original_title?: string
  overview?: string
  release_date?: string
  genres?: string
  vote_average?: string | number
  poster_path?: string | null
  backdrop_path?: string | null
}

type DatasetCredit = {
  movie_id?: string | number
  cast?: string
}

function imageUrl(path?: string | null) {
  return path ? `${TMDB_IMAGE_BASE_URL}${path}` : null
}

function readJsonFile<T>(filePath: string): T[] {
  if (!fs.existsSync(filePath)) return []

  try {
    const raw = fs.readFileSync(filePath, 'utf8')
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed : []
  } catch (error) {
    console.warn(`No se pudo leer dataset ${filePath}:`, (error as Error).message)
    return []
  }
}

function parseJsonArray(value?: string) {
  if (!value) return []

  try {
    const parsed = JSON.parse(value)
    return Array.isArray(parsed) ? parsed : []
  } catch (_) {
    return []
  }
}

function loadDatasetMovies() {
  const moviesPath = path.join(TMDB_DATASET_DIR, 'movies.json')
  const creditsPath = path.join(TMDB_DATASET_DIR, 'credits.json')
  const movies = readJsonFile<DatasetMovie>(moviesPath)
  const credits = readJsonFile<DatasetCredit>(creditsPath)
  const creditsByMovieId = new Map(
    credits
      .filter((credit) => credit.movie_id != null)
      .map((credit) => [String(credit.movie_id), credit]),
  )

  return movies
    .filter((movie) => movie.id != null)
    .map((movie) => ({
      ...movie,
      credits: creditsByMovieId.get(String(movie.id)) || null,
    }))
}

function datasetMovieData(movie: DatasetMovie & { credits?: DatasetCredit | null }) {
  const genres = parseJsonArray(movie.genres)
    .map((genre) => genre?.name)
    .filter(Boolean)
    .join(', ')

  return {
    tmdbId: String(movie.id),
    title: movie.title || movie.original_title || 'Sin titulo',
    description: movie.overview || null,
    releaseDate: movie.release_date || null,
    imageUrl: imageUrl(movie.poster_path),
    backdropUrl: imageUrl(movie.backdrop_path),
    trailerUrl: null,
    type: 'movie',
    category: genres || null,
    rating: Number(movie.vote_average) || 0,
  }
}

function datasetMovieUpdateData(movie: DatasetMovie & { credits?: DatasetCredit | null }) {
  const data = datasetMovieData(movie)

  return {
    title: data.title,
    description: data.description,
    releaseDate: data.releaseDate,
    type: data.type,
    category: data.category,
    rating: data.rating,
    ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
    ...(data.backdropUrl ? { backdropUrl: data.backdropUrl } : {}),
  }
}

function mergeImageData<T extends { imageUrl?: string | null; backdropUrl?: string | null }>(
  data: T,
  metadata: TmdbDetails | null,
) {
  return {
    ...data,
    imageUrl: data.imageUrl || imageUrl(metadata?.poster_path),
    backdropUrl: data.backdropUrl || imageUrl(metadata?.backdrop_path),
  }
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

async function fetchContentImages(tmdbId: string, type: 'movie' | 'tv') {
  try {
    return await tmdbGet<TmdbDetails>(`/${type}/${tmdbId}`)
  } catch (error) {
    console.warn(`No se pudieron consultar imagenes TMDB ${type}/${tmdbId}:`, (error as Error).message)
    return null
  }
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

  for (let seasonIndex = 0; seasonIndex < overrides.length; seasonIndex++) {
    const override = overrides[seasonIndex]
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

  await prisma.content.upsert({
    where: { tmdbId: String(data.id) },
    update: {
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
    create: {
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
  const existing = await prisma.content.findUnique({
    where: { tmdbId },
    select: { id: true, title: true },
  })

  if (existing) {
    console.log(`Serie TMDB ${tmdbId} ya existe (${existing.title}); se conserva.`)
    return
  }

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

async function createDatasetMovies() {
  const datasetMovies = loadDatasetMovies()
  let imported = 0

  for (const movie of datasetMovies) {
    const localData = datasetMovieData(movie)
    const tmdbImages = (!localData.imageUrl || !localData.backdropUrl)
      ? await fetchContentImages(localData.tmdbId, 'movie')
      : null
    const data = mergeImageData(localData, tmdbImages)

    await prisma.content.upsert({
      where: { tmdbId: data.tmdbId },
      update: {
        ...datasetMovieUpdateData(movie),
        ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
        ...(data.backdropUrl ? { backdropUrl: data.backdropUrl } : {}),
      },
      create: data,
    })

    imported++
  }

  console.log(`Peliculas del dataset sincronizadas: ${imported}.`)
}

async function main() {
  console.log('--- Iniciando seed incremental ---')
  console.log('No se eliminaran contenidos existentes.')

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

  console.log('--- Insertando peliculas desde dataset local ---')
  await createDatasetMovies()

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
