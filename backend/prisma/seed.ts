import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('--- Iniciando limpieza total ---')
  await prisma.movie.deleteMany()

  const seriesYpeliculas = [
    {
      title: 'Capitán América: Civil War',
      description: 'Los Vengadores se dividen en dos bandos.',
      videoUrl: 'https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/CivilWar.mp4',
      backdropUrl: 'assets/Images/civilWarBanner.webp',
      imageUrl: 'assets/Images/civilWar.webp',
      rating: 8.2,
      type: 'Pelicula',
      category: 'Acción',
      releaseDate: new Date('2016-04-27'),
    },
    {
      title: 'The Batman',
      description: 'Batman descubre la corrupción en Gotham City.',
      videoUrl: 'https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/TheBatman.mp4',
      backdropUrl: 'assets/Images/TheBatmanPost.webp',
      imageUrl: 'assets/Images/TheBatmanCart.webp',
      rating: 8.9,
      type: 'Pelicula',
      category: 'Suspenso',
      releaseDate: new Date('2022-03-04'),
    },
    {
      title: 'Estamos Muertos',
      description: 'Virus zombi en un instituto.',
      videoUrl: 'https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/EstamosMuertos.mp4',
      backdropUrl: 'assets/Images/EstamosMuertosPost.webp',
      imageUrl: 'assets/Images/EstamosMuertosCart.webp',
      rating: 8.5,
      type: 'Serie',
      category: 'Terror / Horror',
      releaseDate: new Date('2023-05-10'),
    },
    {
      title: 'Stranger Things',
      description: 'Un misterio que involucra experimentos secretos.',
      videoUrl: 'https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/stranger%20Things.mp4',
      backdropUrl: 'assets/Images/strangerThingsPost.webp',
      imageUrl: 'assets/Images/strangerThingsCart.webp',
      rating: 9.1,
      type: 'Serie',
      category: 'Ciencia Ficción',
      releaseDate: new Date('2016-07-15'),
    },
    {
      title: 'Dulce Hogar',
      description: 'Humanos se transforman en monstruos salvajes.',
      videoUrl: 'https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4',
      backdropUrl: 'assets/Images/sweetHomeBanner.webp',
      imageUrl: 'assets/Images/sweetHomeCartel.webp',
      rating: 7.9,
      type: 'Serie',
      category: 'Terror / Fantasía',
      releaseDate: new Date('2020-12-18'),
    }
  ]

  console.log('--- Insertando 5 registros nuevos ---')

  for (const item of seriesYpeliculas) {
    const res = await prisma.movie.create({ data: item })
    console.log(`✅ Registro creado: ${res.title}`)
  }

  console.log('--- SEED FINALIZADO ---')
}

main()
  .catch((e) => {
    console.error(e)
    if (typeof process !== 'undefined') process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })