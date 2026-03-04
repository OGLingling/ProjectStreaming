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

app.post("/login", async (req, res) => {
    console.log("Datos recibidos:", req.body);
    
    try {
        const { email, password, name } = req.body;

        const user = await prisma.user.findUnique({
            where: {
                email: email,
                password: password,
                name: name
            }
        });
        if (user && user.password === password) {
            console.log("✅ Login exitoso para:", user.name);
            
            res.status(200).json({
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email
                }
            });
        } else {
            console.log("❌ Credenciales inválidas");
            res.status(401).json({ error: "Correo o contraseña incorrectos" });
        }
    } catch (error) {
        console.error("❌ Error en el servidor:", error);
        res.status(500).json({ error: "Error interno del servidor" });
    }
});

app.get("/users", async (req, res) => {
    const users = await prisma.user.findMany();
    res.json(users);
});

// AGREGA ESTO EN TU index.js
app.put("/users/:id", async (req, res) => {
  const { id } = req.params; // El ID que viene de la URL
  const { name, profilePic } = req.body; // Los datos que vienen de los TextField de Flutter

  try {
    const userUpdated = await prisma.user.update({
      where: { 
        id: parseInt(id) // Convertimos el ID a número para Neon
      },
      data: { 
        name: name, 
        profilePic: profilePic 
      },
    });

    console.log("Usuario actualizado:", userUpdated);
    res.json(userUpdated); // Le responde a Flutter que todo salió bien
  } catch (error) {
    console.error("Error al actualizar:", error);
    res.status(500).json({ error: "No se pudo actualizar el usuario en la base de datos" });
  }
});