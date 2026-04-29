FROM mcr.microsoft.com/playwright:v1.43.0-jammy

USER root

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install && npx prisma generate

COPY . .

EXPOSE 8080

CMD ["node", "index.js"]
