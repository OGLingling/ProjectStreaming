# Usamos la imagen oficial que ya tiene dependencias de sistema
FROM mcr.microsoft.com/playwright:v1.43.0-jammy

# Instalamos Node.js y dependencias
WORKDIR /app
COPY package*.json ./
RUN npm install

# VITAL: Este comando instala Chromium dentro del contenedor de Render
RUN npx playwright install chromium

COPY . .
RUN npx prisma generate

# Usamos el puerto 8080 que configuraste en Render
EXPOSE 8080

CMD ["node", "index.js"]