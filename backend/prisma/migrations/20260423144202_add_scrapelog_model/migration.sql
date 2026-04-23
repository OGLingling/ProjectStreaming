-- AlterTable
ALTER TABLE "Episode" ADD COLUMN     "duration" TEXT,
ADD COLUMN     "videoUrl" TEXT;

-- CreateTable
CREATE TABLE "ScrapeLog" (
    "id" SERIAL NOT NULL,
    "targetUrl" TEXT NOT NULL,
    "success" BOOLEAN NOT NULL,
    "streamUrl" TEXT,
    "error" TEXT,
    "duration" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ScrapeLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ScrapeLog_targetUrl_idx" ON "ScrapeLog"("targetUrl");

-- CreateIndex
CREATE INDEX "ScrapeLog_success_idx" ON "ScrapeLog"("success");

-- CreateIndex
CREATE INDEX "ScrapeLog_createdAt_idx" ON "ScrapeLog"("createdAt");
