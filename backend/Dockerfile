FROM ghcr.io/puppeteer/puppeteer:22.6.0

# Cambiar a usuario root para instalar dependencias si fuera necesario
USER root

# Configurar directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias e instalar
COPY package*.json ./
RUN npm install

# Copiar el resto del código
COPY . .

# Railway usa la variable PORT automáticamente, pero exponemos el 8080 por si acaso
EXPOSE 8080

# Comando para arrancar la app
CMD ["node", "index.js"]