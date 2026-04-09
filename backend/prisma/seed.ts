import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('--- Iniciando limpieza total ---')
  try {
    await prisma.movie.deleteMany()
  } catch (e) {
    console.log('No había registros previos.')
  }

  const seriesYpeliculas = [
    // --- SERIES DE TV (Basado en ratings reales de TMDB/IMDb) ---
    {
      tmdbId: "76479",
      title: "The Boys",
      description: "A group of vigilantes known informally as “The Boys” set out to take down corrupt superheroes with no more than blue-collar grit and a willingness to fight dirty.",
      imageUrl: "https://image.tmdb.org/t/p/w500/in1R2dDc421JxsoRWaIIAqVI2KE.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/bq28ajZaoMyzEIm6REelqyqtEDZ.jpg",
      type: "tv",
      category: "Sci-Fi & Fantasy",
      releaseDate: "2019-07-25",
      rating: 8.47, 
    },
    {
      tmdbId: "65942",
      title: "Re:ZERO -Starting Life in Another World-",
      description: "Natsuki Subaru, an ordinary high school student, is transported to another world where he meets a beautiful girl with silver hair.",
      imageUrl: "https://image.tmdb.org/t/p/w500/aRwmcX36r1ZpR5Xq5mmFcpUDQ8J.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/x6y59dJBE1o0r4YRsWVQXE2nnlB.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2016-04-04",
      rating: 8.30,
    },
    {
      tmdbId: "95557",
      title: "Invincible",
      description: "Mark Grayson is a normal teenager except for the fact that his father is the most powerful superhero on the planet.",
      imageUrl: "https://image.tmdb.org/t/p/w500/4tblBrslcKSifMVZ3TmtT2ukMor.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/9qrroces8C6R9aKr08hACNPVXdZ.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2021-03-25",
      rating: 8.66,
    },
    {
      tmdbId: "202555",
      title: "Daredevil: Born Again",
      description: "Matt Murdock, a blind lawyer with heightened abilities, fights for justice in New York while Wilson Fisk pursues political endeavors.",
      imageUrl: "https://image.tmdb.org/t/p/w500/xDUoAsU8lQHOOoRkFiBuarmACDN.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/qrTAc0ZtQ859Qu5O8cixJzNJpQs.jpg",
      type: "tv",
      category: "Drama",
      releaseDate: "2025-03-04",
      rating: 8.80, // Estimado por crítica inicial
    },
    {
      tmdbId: "37854",
      title: "One Piece",
      description: "Monkey D. Luffy sets out to find the legendary One Piece treasure and become the King of the Pirates.",
      imageUrl: "https://image.tmdb.org/t/p/w500/uiIB9ctqZFbfRXXimtpmZb5dusi.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/2rmK7mnchw9Xr3XdiTFSxTTLXqv.jpg",
      type: "tv",
      category: "Action & Adventure",
      releaseDate: "1999-10-20",
      rating: 8.73,
    },
    {
      tmdbId: "95479",
      title: "JUJUTSU KAISEN",
      description: "A boy swallows a cursed finger to save a friend and becomes a vessel for a powerful curse, joining a secret school of sorcerers.",
      imageUrl: "https://image.tmdb.org/t/p/w500/6qQzMJG27XOJsyAEEIisoJB45j2.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/qpin8cASXEVtwhzNsprHYFiOAGk.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2020-10-03",
      rating: 8.58,
    },
    {
      tmdbId: "127529",
      title: "Bloodhounds",
      description: "Two young boxers band together with a benevolent moneylender to take down a ruthless loan shark.",
      imageUrl: "https://image.tmdb.org/t/p/w500/yu4oHDi6kO3cYXdmEnYT6SibATj.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/zhsEnDNCQX5dlI2wbKzV90pV0B9.jpg",
      type: "tv",
      category: "Action",
      releaseDate: "2023-06-09",
      rating: 8.35,
    },
    {
      tmdbId: "209867",
      title: "Frieren: Beyond Journey's End",
      description: "After the party of heroes defeated the Demon King, elf mage Frieren embarks on a new journey to understand humanity.",
      imageUrl: "https://image.tmdb.org/t/p/w500/dqZENchTd7lp5zht7BdlqM7RBhD.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/rBOnrVlck7BIlGeWVlzYiZeg4l2.jpg",
      type: "tv",
      category: "Animation",
      releaseDate: "2023-09-29",
      rating: 8.94,
    },

    // --- PELÍCULAS ---
    {
      tmdbId: "1226863",
      title: "The Super Mario Galaxy Movie",
      description: "Mario and Luigi face a fresh threat in Bowser Jr. and the Koopalings.",
      imageUrl: "https://image.tmdb.org/t/p/w500/eJGWx219ZcEMVQJhAgMiqo8tYY.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/kxQiIJ4gVcD3K6o14MJ72p5yRcE.jpg",
      type: "movie",
      category: "Adventure",
      releaseDate: "2026-04-01",
      rating: 7.8, // Estimado
    },
    {
      tmdbId: "936075",
      title: "Michael",
      description: "Discover the story of Michael Jackson, the King of Pop.",
      imageUrl: "https://image.tmdb.org/t/p/w500/3Qud19bBUrrJAzy0Ilm8gRJlJXP.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/xBT0oNq6rsTFv4SxG5uGRIEOrq6.jpg",
      type: "movie",
      category: "Music",
      releaseDate: "2026-04-22",
      rating: 8.5, // Altas expectativas
    },
    {
      tmdbId: "83533",
      title: "Avatar: Fire and Ash",
      description: "In the wake of the war, Jake Sully and Neytiri face the Ash People.",
      imageUrl: "https://image.tmdb.org/t/p/w500/bRBeSHfGHwkEpImlhxPmOcUsaeg.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/iN41Ccw4DctL8npfmYg1j5Tr1eb.jpg",
      type: "movie",
      category: "Adventure",
      releaseDate: "2025-12-17",
      rating: 7.9,
    },
    {
      tmdbId: "1084242",
      title: "Zootopia 2",
      description: "Judy Hopps and Nick Wilde return to solve a new case.",
      imageUrl: "https://image.tmdb.org/t/p/w500/oJ7g2CifqpStmoYQyaLQgEU32qO.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/lgotja3xMoJZbynwHfcQcJAEMWH.jpg",
      type: "movie",
      category: "Animation",
      releaseDate: "2025-11-26",
      rating: 8.2,
    }
  ]

  console.log(`--- Insertando ${seriesYpeliculas.length} registros ---`)

  for (const item of seriesYpeliculas) {
    const res = await prisma.movie.create({ data: item })
    console.log(`✅ Creado: ${res.title} (Rating: ${res.rating})`)
  }

  console.log('--- SEED FINALIZADO CON ÉXITO ---')
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })