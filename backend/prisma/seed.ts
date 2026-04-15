import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// Función para generar episodios con títulos dinámicos
const generateEpisodes = (count: number, prefix: string) => {
  return Array.from({ length: count }, (_, i) => ({
    episodeNumber: i + 1,
    title: `${prefix} - Ep. ${i + 1}`,
    videoUrl: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
    duration: "24m"
  }));
};

async function main() {
  console.log('--- Iniciando limpieza total ---')
  await prisma.content.deleteMany()
  console.log('✅ Base de datos limpiada.')

  const series = [
    {
      tmdbId: "209867",
      title: "Frieren: Beyond Journey's End",
      description: "La maga elfa Frieren y su viaje para entender el corazón humano.",
      imageUrl: "https://image.tmdb.org/t/p/w500/dqZENchTd7lp5zht7BdlqM7RBhD.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/rBOnrVlck7BIlGeWVlzYiZeg4l2.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2023-09-29",
      rating: 8.9,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Temporada 1", episodes: { create: generateEpisodes(28, "Frieren T1") } }
        ]
      }
    },
    {
      tmdbId: "65942",
      title: "Re:ZERO -Starting Life in Another World-",
      description: "Subaru Natsuki jura salvar a la chica que ama volviendo de la muerte.",
      imageUrl: "https://image.tmdb.org/t/p/w500/aRwmcX36r1ZpR5Xq5mmFcpUDQ8J.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2016-04-04",
      rating: 8.3,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Temporada 1", episodes: { create: generateEpisodes(25, "Re:Zero T1") } },
          { seasonNumber: 2, title: "Temporada 2", episodes: { create: generateEpisodes(25, "Re:Zero T2") } },
          { seasonNumber: 3, title: "Temporada 3", episodes: { create: generateEpisodes(16, "Re:Zero T3") } }
        ]
      }
    },
    {
      tmdbId: "37854",
      title: "One Piece",
      description: "La gran era de los piratas y la búsqueda del tesoro legendario.",
      imageUrl: "https://image.tmdb.org/t/p/w500/uiIB9ctqZFbfRXXimtpmZb5dusi.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "1999-10-20",
      rating: 8.7,
      seasons: {
        create: [
          { seasonNumber: 1, title: "East Blue a Egghead", episodes: { create: generateEpisodes(1120, "One Piece") } }
        ]
      }
    },
    {
      tmdbId: "76479",
      title: "The Boys",
      description: "A group of vigilantes set out to take down corrupt superheroes.",
      imageUrl: "https://image.tmdb.org/t/p/w500/in1R2dDc421JxsoRWaIIAqVI2KE.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/bq28ajZaoMyzEIm6REelqyqtEDZ.jpg",
      type: "tv",
      category: "Sci-Fi",
      releaseDate: "2019-07-25",
      rating: 8.4,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Season 1", episodes: { create: generateEpisodes(8, "The Boys S1") } },
          { seasonNumber: 2, title: "Season 2", episodes: { create: generateEpisodes(8, "The Boys S2") } },
          { seasonNumber: 3, title: "Season 3", episodes: { create: generateEpisodes(8, "The Boys S3") } },
          { seasonNumber: 4, title: "Season 4", episodes: { create: generateEpisodes(8, "The Boys S4") } }
        ]
      }
    },
    {
      tmdbId: "95557",
      title: "Invincible",
      description: "Mark comienza a desarrollar poderes propios bajo la tutela de su padre.",
      imageUrl: "https://image.tmdb.org/t/p/w500/4tblBrslcKSifMVZ3TmtT2ukMor.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/9qrroces8C6R9aKr08hACNPVXdZ.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2021-03-25",
      rating: 8.6,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Temporada 1", episodes: { create: generateEpisodes(8, "Invincible T1") } },
          { seasonNumber: 2, title: "Temporada 2", episodes: { create: generateEpisodes(8, "Invincible T2") } },
          { seasonNumber: 3, title: "Temporada 3", episodes: { create: generateEpisodes(8, "Invincible T3") } },
          { seasonNumber: 4, title: "Temporada 4", episodes: { create: generateEpisodes(8, "Invincible T4") } }
        ]
      }
    },
    {
      tmdbId: "85552",
      title: "Euphoria",
      description: "Drama juvenil sobre amor, drogas y redes sociales.",
      imageUrl: "https://image.tmdb.org/t/p/w500/aJrG7OkoTMPWG5c8opz8a93AZPY.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/GN2KFXiHPVV6sIw4v2P2pqCJty.jpg",
      type: "tv",
      category: "Drama",
      releaseDate: "2019-06-16",
      rating: 8.3,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Season 1", episodes: { create: generateEpisodes(8, "Euphoria S1") } },
          { seasonNumber: 2, title: "Season 2", episodes: { create: generateEpisodes(8, "Euphoria S2") } }
        ]
      }
    },
    {
      tmdbId: "79744",
      title: "The Rookie",
      description: "El novato más viejo del LAPD enfrenta nuevos retos.",
      imageUrl: "https://image.tmdb.org/t/p/w500/70kTz0OmjjZe7zHvIDrq2iKW7PJ.jpg",
      type: "tv",
      category: "Crime",
      releaseDate: "2018-10-16",
      rating: 8.5,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Season 1", episodes: { create: generateEpisodes(20, "Rookie S1") } },
          { seasonNumber: 2, title: "Season 2", episodes: { create: generateEpisodes(20, "Rookie S2") } },
          { seasonNumber: 3, title: "Season 3", episodes: { create: generateEpisodes(14, "Rookie S3") } },
          { seasonNumber: 4, title: "Season 4", episodes: { create: generateEpisodes(22, "Rookie S4") } },
          { seasonNumber: 5, title: "Season 5", episodes: { create: generateEpisodes(22, "Rookie S5") } },
          { seasonNumber: 6, title: "Season 6", episodes: { create: generateEpisodes(10, "Rookie S6") } }
        ]
      }
    },
    {
      tmdbId: "95479",
      title: "JUJUTSU KAISEN",
      description: "Yuji Itadori se adentra en el mundo de las maldiciones.",
      imageUrl: "https://image.tmdb.org/t/p/w500/6qQzMJG27XOJsyAEEIisoJB45j2.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2020-10-03",
      rating: 8.6,
      seasons: {
        create: [
          { seasonNumber: 1, title: "Season 1", episodes: { create: generateEpisodes(24, "JJK S1") } },
          { seasonNumber: 2, title: "Season 2", episodes: { create: generateEpisodes(23, "JJK S2") } }
        ]
      }
    }
  ];

  const peliculas = [
    {
      tmdbId: "687163",
      title: "Project Hail Mary",
      description: "Ryland Grace despierta en una nave espacial para salvar la Tierra.",
      imageUrl: "https://image.tmdb.org/t/p/w500/yihdXomYb5kTeSivtFndMy5iDmf.jpg",
      type: "movie",
      category: "Sci-Fi",
      releaseDate: "2026-03-15",
      rating: 8.2
    },
    {
      tmdbId: "1226863",
      title: "The Super Mario Galaxy Movie",
      description: "Mario y Luigi viajan por las estrellas para detener a Bowser Jr.",
      imageUrl: "https://image.tmdb.org/t/p/w500/eJGWx219ZcEMVQJhAgMiqo8tYY.jpg",
      type: "movie",
      category: "Adventure",
      releaseDate: "2026-04-01",
      rating: 6.8
    },
    {
      tmdbId: "936075",
      title: "Michael",
      description: "La biografía definitiva de Michael Jackson.",
      imageUrl: "https://image.tmdb.org/t/p/w500/3Qud19bBUrrJAzy0Ilm8gRJlJXP.jpg",
      type: "movie",
      category: "Music",
      releaseDate: "2026-04-22",
      rating: 8.5
    },
    {
      tmdbId: "980431",
      title: "Avatar: Aang, The Last Airbender",
      description: "El último Maestro del Aire busca salvar su cultura.",
      imageUrl: "https://image.tmdb.org/t/p/w500/gPiyTLo5GGwtJl0L8TlaJF9r0KE.jpg",
      type: "movie",
      category: "Animation",
      releaseDate: "2026-10-09",
      rating: 7.0
    },
    {
      tmdbId: "1314481",
      title: "The Devil Wears Prada 2",
      description: "Miranda Priestly navega el declive de las revistas tradicionales.",
      imageUrl: "https://image.tmdb.org/t/p/w500/p35IoKfBtJDNiWJMO8ZEtIMZSfW.jpg",
      type: "movie",
      category: "Comedy",
      releaseDate: "2026-04-29",
      rating: 6.5
    }
  ];

  console.log('--- Insertando Series ---')
  for (const s of series) {
    await prisma.content.create({ data: s });
    console.log(`✅ Serie: ${s.title}`);
  }

  console.log('--- Insertando Películas ---')
  for (const p of peliculas) {
    await prisma.content.create({ data: p });
    console.log(`✅ Película: ${p.title}`);
  }

  console.log('--- SEED FINALIZADO CON ÉXITO ---')
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); })