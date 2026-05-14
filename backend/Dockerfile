FROM mcr.microsoft.com/playwright:v1.43.0-jammy
USER root
WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npx playwright install chromium --with-deps
COPY . .
RUN npx prisma generate
EXPOSE 8080
CMD ["node", "index.js"]