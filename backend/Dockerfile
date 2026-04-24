FROM ghcr.io/puppeteer/puppeteer:22.6.0

USER root

WORKDIR /app

# 1. Copiamos los archivos de configuración
COPY package*.json ./

# 2. COPIAMOS LA CARPETA PRISMA (Esto es lo que faltaba)
# Esto asegura que el esquema esté ahí cuando npm install lo busque
COPY prisma ./prisma/

# 3. Instalamos las dependencias
# Usamos --foreground-scripts para ver errores si fallan
RUN npm install

# 4. Copiamos el resto del código
COPY . .

EXPOSE 8080

CMD ["node", "index.js"]