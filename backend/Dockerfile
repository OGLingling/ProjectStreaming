FROM ghcr.io/puppeteer/puppeteer:22.6.0

USER root

WORKDIR /app

COPY package*.json ./

COPY prisma ./prisma/

RUN npm install

COPY . .

EXPOSE 8080

CMD ["node", "index.js"]