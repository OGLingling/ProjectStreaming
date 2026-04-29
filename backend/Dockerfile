FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

# Copiamos dependencias y carpeta prisma
COPY package*.json ./
COPY prisma ./prisma/

# Instalamos dependencias de la app
RUN npm install

# Instalamos SOLO chromium para ahorrar espacio en Railway
RUN npx playwright install chromium --with-deps

# Copiamos el resto del proyecto
COPY . .

EXPOSE 8080

CMD ["node", "index.js"]