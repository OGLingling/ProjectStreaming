const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getWatchlist = async (req, res) => {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId requerido" });

    try {
        const list = await prisma.watchlist.findMany({
            where: { userId: userId },
            include: { 
                content: true // Realiza el JOIN con la tabla Content en Neon
            } 
        });

        const formattedList = list.map(item => ({
            // 1. ID INTERNO: Necesario para que el botón de eliminar (X) funcione
            id: item.contentId, 

            // 2. ID DE TMDB: El campo que falta en tu error actual
            // Extraído directamente de la relación con 'Content'
            tmdb_id: item.content?.tmdb_id, 

            // 3. METADATOS: Para mostrar correctamente el poster y título
            title: item.content?.title || "Sin título",
            image: item.content?.image || item.content?.posterPath || "",
            
            // 4. TIPO: Importante para que TMDB sepa si buscar 'movie' o 'tv'
            type: item.content?.type || "movie" 
        }));

        res.status(200).json(formattedList);
    } catch (error) {
        // Log para depuración en Railway
        console.error("Error en getWatchlist:", error);
        res.status(500).json({ error: error.message });
    }
};

const toggleWatchlist = async (req, res) => {
    const { userId, contentId } = req.body;
    if (!userId || !contentId) return res.status(400).json({ error: "Datos incompletos" });

    try {
        const existing = await prisma.watchlist.findFirst({
            where: { userId, contentId: parseInt(contentId) }
        });

        if (existing) {
            await prisma.watchlist.delete({ where: { id: existing.id } });
            return res.status(200).json({ message: "Eliminado" });
        } else {
            const newItem = await prisma.watchlist.create({
                data: { userId, contentId: parseInt(contentId) }
            });
            return res.status(201).json(newItem);
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Exportación estilo CommonJS
module.exports = {
    getWatchlist,
    toggleWatchlist
};