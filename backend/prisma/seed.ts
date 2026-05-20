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
]

const movieTmdbIds = [
  '687163',  // Project Hail Mary
  '1226863', // The Super Mario Galaxy Movie
  '936075',  // Michael
  '980431',  // Avatar: Aang, The Last Airbender
  '1314481', // The Devil Wears Prada 2
]

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
  const playableSeasons = seasons.filter(
    (season) => season.season_number > 0 && (season.episode_count || 0) > 0,
  )

  const seasonsForCreate = []

  for (const season of playableSeasons) {
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
