-- AlterTable
ALTER TABLE "Content" ADD COLUMN     "streamExpiresAt" TIMESTAMP(3),
ADD COLUMN     "streamSource" TEXT,
ADD COLUMN     "videoUrl" TEXT;

-- AlterTable
ALTER TABLE "Episode" ADD COLUMN     "streamExpiresAt" TIMESTAMP(3),
ADD COLUMN     "streamSource" TEXT;

-- CreateTable
CREATE TABLE "ScrapeJob" (
    "id" SERIAL NOT NULL,
    "tmdbId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "season" INTEGER NOT NULL DEFAULT 1,
    "episode" INTEGER NOT NULL DEFAULT 1,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScrapeJob_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ScrapeJob_status_createdAt_idx" ON "ScrapeJob"("status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ScrapeJob_tmdbId_type_season_episode_key" ON "ScrapeJob"("tmdbId", "type", "season", "episode");

-- CreateIndex
CREATE INDEX "Content_streamExpiresAt_idx" ON "Content"("streamExpiresAt");

-- CreateIndex
CREATE INDEX "Episode_streamExpiresAt_idx" ON "Episode"("streamExpiresAt");
