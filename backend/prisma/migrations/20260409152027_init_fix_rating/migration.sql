-- CreateEnum
CREATE TYPE "PlanType" AS ENUM ('basico', 'estandar', 'premium');

-- CreateTable
CREATE TABLE "Movie" (
    "id" SERIAL NOT NULL,
    "tmdb_id" TEXT,
    "imdb_id" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "releaseDate" TEXT,
    "imageUrl" TEXT,
    "backdropUrl" TEXT,
    "trailer_url" TEXT,
    "category" TEXT,
    "type" TEXT NOT NULL DEFAULT 'movie',
    "rating" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Movie_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT DEFAULT '123456',
    "name" TEXT NOT NULL,
    "profilePic" TEXT DEFAULT 'assets/avatars/usuario5.webp',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "plan" "PlanType" NOT NULL DEFAULT 'basico',
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "pin" TEXT,
    "pinExpiresAt" TIMESTAMP(3),
    "language" TEXT NOT NULL DEFAULT 'es',
    "parentalPin" TEXT,
    "maturityLevel" TEXT NOT NULL DEFAULT '18+',
    "subtitleSize" TEXT NOT NULL DEFAULT 'medium',
    "autoPlay" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Movie_tmdb_id_key" ON "Movie"("tmdb_id");

-- CreateIndex
CREATE UNIQUE INDEX "Movie_imdb_id_key" ON "Movie"("imdb_id");

-- CreateIndex
CREATE INDEX "Movie_title_idx" ON "Movie"("title");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
