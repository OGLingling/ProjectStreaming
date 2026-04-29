FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

# Al cambiar el Root Directory a /backend, 
# los archivos ya están "a la mano"
COPY package*.json ./
COPY prisma ./prisma/

RUN npm install
RUN npx playwright install chromium --with-deps

# Copiamos el resto del código del servidor
COPY . .

# Generamos el cliente de Prisma por si acaso
RUN npx prisma generate

EXPOSE 8080
CMD ["node", "index.js"]