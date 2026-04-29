# Imagen oficial de Playwright con todas las dependencias de Linux
FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

# Copia de archivos de configuración y Prisma
COPY package*.json ./
COPY prisma ./prisma/

# Instalación de dependencias y el navegador Chromium
RUN npm install
RUN npx playwright install chromium --with-deps

# Copia del código fuente y ejecución
COPY . .

EXPOSE 8080
CMD ["node", "index.js"]