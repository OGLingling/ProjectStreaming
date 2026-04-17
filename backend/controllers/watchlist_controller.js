const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getWatchlist = async (req, res) => {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId requerido" });

    try {
        const list = await prisma.watchlist.findMany({
            where: { userId: userId },
            include: { content: true } // Esto hace el JOIN con la tabla Content
        });

        const formattedList = list.map(item => ({
            // Mantenemos el ID de la tabla para el toggle si quieres
            id: item.contentId, 
            
            // AGREGAMOS EL TMDB_ID (Este es el que soluciona tu error en Flutter)
            tmdb_id: item.content?.tmdb_id, 
            
            title: item.content?.title || "Sin título",
            
            // Asegúrate de que el campo sea 'image' para que coincida con tu Flutter
            image: item.content?.image || item.content?.posterPath || "",
            
            // También enviamos el tipo para que TMDB sepa si es movie o tv
            type: item.content?.type || "movie" 
        }));

        res.status(200).json(formattedList);
    } catch (error) {
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