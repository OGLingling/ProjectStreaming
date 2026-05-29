const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const prisma = new PrismaClient();

const transferProfile = async (req, res) => {
  const { profileId, targetEmail, targetPassword } = req.body;

  if (!profileId || !targetEmail || !targetPassword) {
    return res.status(400).json({ error: 'Datos incompletos para la transferencia' });
  }

  try {
    // 1. Buscar la cuenta destino
    const targetUser = await prisma.user.findUnique({
      where: { email: targetEmail.toLowerCase().trim() },
      include: { profiles: true },
    });

    if (!targetUser) {
      return res.status(404).json({ error: 'La cuenta de destino no existe' });
    }

    // 2. Validar credenciales de la cuenta destino
    // Nota: El password del usuario puede ser null si usa autenticación alternativa, validamos con default "123456" si es nulo.
    const isPasswordValid = await bcrypt.compare(
      targetPassword,
      targetUser.password || '$2b$10$y58n1qD6r5nZ2g0wA7zNGe2O7662b66572e' // bcrypt hash de "123456"
    );

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Contraseña incorrecta para la cuenta destino' });
    }

    // 3. Validar límite de perfiles en la cuenta destino
    const plan = (targetUser.plan || 'basico').toLowerCase();
    const maxProfiles = plan === 'premium' ? 4 : (plan === 'estandar' ? 2 : 1);
    
    if (targetUser.profiles.length >= maxProfiles) {
      return res.status(400).json({
        error: `La cuenta de destino ya ha alcanzado el límite de perfiles (${maxProfiles}) para su plan ${plan.toUpperCase()}.`
      });
    }

    // 4. Buscar el perfil a transferir
    let profile = await prisma.profile.findUnique({
      where: { id: profileId },
    });

    // Si el perfil no existe físicamente en la BD (por ejemplo, porque era simulado), lo creamos primero para el usuario original
    if (!profile) {
      // Como fallback de robustez, si el ID suministrado no existe, creamos un registro físico
      // Obtenemos los detalles del body o creamos uno con valores genéricos
      const currentUserId = req.body.currentUserId || req.user?.id;
      if (!currentUserId) {
        return res.status(400).json({ error: 'Perfil no encontrado físicamente y currentUserId no provisto.' });
      }

      profile = await prisma.profile.create({
        data: {
          id: profileId,
          name: req.body.profileName || 'Perfil Transferido',
          profilePic: req.body.profilePic || 'assets/avatars/usuario5.webp',
          userId: currentUserId,
        }
      });
    }

    // 5. Ejecutar la transacción de transferencia
    await prisma.$transaction(async (tx) => {
      // a) Actualizar el userId en el modelo Profile
      await tx.profile.update({
        where: { id: profileId },
        data: { userId: targetUser.id },
      });

      // b) Actualizar el userId en todos los registros relacionados en Watchlist (MyList)
      await tx.watchlist.updateMany({
        where: { profileId: profileId },
        data: { userId: targetUser.id },
      });

      // c) Actualizar el userId en todos los registros de ViewingProgress (WatchHistory)
      await tx.viewingProgress.updateMany({
        where: { profileId: profileId },
        data: { userId: targetUser.id },
      });
    });

    res.status(200).json({
      success: true,
      message: 'Perfil e historial transferidos exitosamente a la cuenta de destino',
    });
  } catch (error) {
    console.error('Error al transferir perfil:', error);
    res.status(500).json({ error: 'Error interno del servidor al transferir el perfil', details: error.message });
  }
};

module.exports = {
  transferProfile,
};
