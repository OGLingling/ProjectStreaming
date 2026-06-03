const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();
const bcryptHashPattern = /^\$2[aby]\$\d{2}\$/;

function isBcryptHash(value) {
    return typeof value === 'string' && bcryptHashPattern.test(value);
}

async function main() {
    const users = await prisma.user.findMany({
        where: {
            password: {
                not: null
            }
        },
        select: {
            id: true,
            email: true,
            password: true
        }
    });

    let updated = 0;
    let skippedHashed = 0;
    let skippedEmpty = 0;

    for (const user of users) {
        const currentPassword = String(user.password || '');

        if (!currentPassword.trim()) {
            skippedEmpty++;
            continue;
        }

        if (isBcryptHash(currentPassword)) {
            skippedHashed++;
            continue;
        }

        const hashedPassword = await bcrypt.hash(currentPassword, 10);

        await prisma.user.update({
            where: { id: user.id },
            data: { password: hashedPassword }
        });

        updated++;
        console.log(`Hashed password for ${user.email}`);
    }

    console.log(
        `Done. Updated: ${updated}. Already hashed: ${skippedHashed}. Empty: ${skippedEmpty}.`
    );
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
