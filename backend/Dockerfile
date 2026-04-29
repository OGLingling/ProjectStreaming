FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

# Copiamos los archivos de configuración
COPY package*.json ./
# Si usas prisma, copiamos la carpeta
COPY prisma ./prisma/

# Instalamos dependencias
RUN npm install

# ESTA LÍNEA ES VITAL: Instala las librerías de sistema para Chromium
RUN npx playwright install --with-deps chromium

# Copiamos el resto del código
COPY . .

# Generamos el cliente de Prisma (si aplica)
RUN npx prisma generate

# Railway inyecta la variable PORT, asegúrate de que tu código use process.env.PORT
EXPOSE 8080

CMD ["node", "index.js"]