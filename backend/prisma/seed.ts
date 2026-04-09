import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('--- Iniciando limpieza total ---')
  await prisma.movie.deleteMany()

  const seriesYpeliculas = [
    {
      tmdbId: "76479",
      title: "The Boys",
      description: "A group of vigilantes known informally as “The Boys” set out to take down corrupt superheroes with no more than blue-collar grit and a willingness to fight dirty.",
      imageUrl: "https://image.tmdb.org/t/p/w500/in1R2dDc421JxsoRWaIIAqVI2KE.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/bq28ajZaoMyzEIm6REelqyqtEDZ.jpg",
      type: "tv",
      category: "Sci-Fi & Fantasy",
      releaseDate: "2019-07-25",
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
    },
    {
      tmdbId: "127529",
      title: "Bloodhounds",
      description: "Two young boxers band together with a benevolent moneylender to take down a ruthless loan shark who preys on the financially desperate.",
      imageUrl: "https://image.tmdb.org/t/p/w500/yu4oHDi6kO3cYXdmEnYT6SibATj.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/zhsEnDNCQX5dlI2wbKzV90pV0B9.jpg",
      type: "tv",
      category: "Action",
      releaseDate: "2023-06-09",
    },
    {
      tmdbId: "85552",
      title: "Euphoria",
      description: "A group of high school students navigate love and friendships in a world of drugs, sex, trauma, and social media.",
      imageUrl: "https://image.tmdb.org/t/p/w500/zvVt4xPUDR6SglHvUa8ECg8uREV.jpg",
      backdropUrl: "https://image.tmdb.org/t/p/original/lcJ8S992xGr20KfNCbY4Fg3Xz6s.jpg",
      type: "tv",
      category: "Drama",
      releaseDate: "2019-06-16",
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
    }
  ]

  console.log(`--- Insertando ${seriesYpeliculas.length} registros desde TMDB ---`)

  for (const item of seriesYpeliculas) {
    const res = await prisma.movie.create({ data: item })
    console.log(`✅ Registro creado: ${res.title} (TMDB ID: ${res.tmdbId})`)
  }

  console.log('--- SEED FINALIZADO ---')
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })