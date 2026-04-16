import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

export const getWatchlist = async (req, res) => {
    const { userId } = req.query;
    try {
        const list = await prisma.watchlist.findMany({
            where: { userId: userId },
            // Si tienes relación con la tabla Content, puedes incluirla
            include: { content: true } 
        });
        // Mapeamos para que el frontend reciba el formato que espera
        const formattedList = list.map(item => ({
            id: item.contentId,
            title: item.content?.title || "Sin título",
            image: item.content?.posterPath || ""
        }));
        res.status(200).json(formattedList);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

export const toggleWatchlist = async (req, res) => {
    const { userId, contentId } = req.body;
    try {
        const existing = await prisma.watchlist.findFirst({
            where: { userId, contentId }
        });

        if (existing) {
            await prisma.watchlist.delete({ where: { id: existing.id } });
            return res.status(200).json({ message: "Eliminado" });
        } else {
            const newItem = await prisma.watchlist.create({
                data: { userId, contentId }
            });
            return res.status(201).json(newItem);
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};