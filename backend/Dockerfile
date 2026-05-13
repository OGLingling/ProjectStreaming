FROM mcr.microsoft.com/playwright:v1.43.0-jammy

WORKDIR /app

# Primero copiamos TODO (incluyendo la carpeta prisma)
COPY . .

# Al ejecutar install, el postinstall de Prisma encontrará el archivo correctamente
RUN npm install

RUN npx playwright install chromium

EXPOSE 8080
CMD ["node", "index.js"]