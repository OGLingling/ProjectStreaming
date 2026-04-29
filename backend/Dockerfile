FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

COPY package*.json ./

# Instalamos sin ejecutar scripts automáticos que rompan el build
RUN npm install --ignore-scripts

RUN npx playwright install chromium

COPY . .

# Generamos Prisma localmente (esto no necesita conexión a la BD activa)
RUN npx prisma generate

EXPOSE 8080

CMD ["node", "index.js"]