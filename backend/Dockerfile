FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root
WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install

RUN npx playwright install chromium --with-deps

COPY . .

EXPOSE 8080
CMD ["node", "index.js"]