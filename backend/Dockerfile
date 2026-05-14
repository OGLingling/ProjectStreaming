FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

# Copiar manifiestos primero para aprovechar el cache de Docker
COPY package*.json ./
COPY prisma ./prisma/

# Instalar dependencias de Node
RUN npm install

# Instalar browsers de Playwright (Chromium + sus dependencias del SO)
# playwright-extra usa el mismo binario que playwright nativo
RUN npx playwright install chromium --with-deps

# Copiar el resto del código
COPY . .

EXPOSE 8080
CMD ["node", "index.js"]