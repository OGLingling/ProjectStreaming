FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

COPY package*.json ./

# Sin --ignore-scripts para que los postinstalls corran
RUN npm install

# Playwright ya viene en la imagen base, pero reinstalamos chromium explícito
RUN npx playwright install chromium --with-deps

COPY . .

RUN npx prisma generate

# Variable que usará tu código para encontrar el ejecutable
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

EXPOSE 8080
CMD ["node", "index.js"]