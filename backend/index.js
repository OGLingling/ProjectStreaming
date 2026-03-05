const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();

app.use(cors());
app.use(express.json()); // Vital para que el body no llegue {}

// RUTA PARA CREAR PELÍCULA
app.post("/movies", async (req, res) => {
    console.log("Datos recibidos:", req.body);
    
    try {
        const { title, description, releaseDate, rating, imageUrl, category } = req.body;

        const nuevaPelicula = await prisma.movie.create({
            data: {
                title: title,
                description: description,
                releaseDate: new Date(releaseDate), 
                rating: parseFloat(rating),
                imageUrl: imageUrl,
                category: category
            }
        });

        res.status(201).json(nuevaPelicula);
        console.log("✅ Película guardada en Neon!");
    } catch (error) {
        console.error("❌ Error al guardar:", error);
        res.status(500).json({ error: "No se pudo guardar la película" });
    }
});

// RUTA PARA VER PELÍCULAS
app.get('/movies', async (req, res) => {
  const { category } = req.query; // Aquí recibimos el "hollywood", "series", etc.

  try {
    const movies = await prisma.movie.findMany({
      where: category ? {
        category: {
          equals: category,
          mode: 'insensitive', // Esto hace que no importe si es "Hollywood" o "hollywood"
        },
      } : {}, // Si no hay categoría en la URL, trae TODAS (para la Home)
    });
    res.json(movies);
  } catch (error) {
    console.error("Error al filtrar:", error);
    res.status(500).json({ error: "Error al obtener las películas" });
  }
});

app.listen(3000, () => {
    console.log("🚀 Servidor corriendo en http://localhost:3000");
});

app.post("/sync-user", async (req, res) => {
    console.log("Sincronizando usuario:", req.body);
    
    try {
        const { id, email, name, isVerified } = req.body;

        const user = await prisma.user.upsert({
            where: { id: id },
            update: {isVerified: isVerified},
            create: {
                id: id,
                email: email,
                name: name || "Usuario de Netflix",
                isVerified: isVerified || false,
            },
        });

        console.log(`✅ Usuario ${user.email} sincronizado (Verificado: ${user.isVerified})`);
        
        res.status(200).json({
            message: "Usuario sincronizado correctamente",
            user: user
        });

    } catch (error) {
        console.error("❌ Error en Neon/Prisma:", error);
        res.status(500).json({ error: "Error al sincronizar con la base de datos" });
    }
});

app.get("/users", async (req, res) => {
    const users = await prisma.user.findMany();
    res.json(users);
});

app.put("/users/:id", async (req, res) => {
  const { id } = req.params;
  const { name, profilePic, plan } = req.body;

  try {
    const userUpdated = await prisma.user.update({
      where: { 
        id: id // Convertimos el ID a número para Neon
      },
      data: { 
        name: name, 
        profilePic: profilePic,
        plan: plan
      },
    });

    console.log("Usuario actualizado:", userUpdated.name);
    res.json(userUpdated); // Le responde a Flutter que todo salió bien
  } catch (error) {
    console.error("Error al actualizar:", error);
    res.status(500).json({ error: "No se pudo actualizar el usuario en la base de datos" });
  }
});