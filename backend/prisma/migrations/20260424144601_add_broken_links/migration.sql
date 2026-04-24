-- CreateTable
CREATE TABLE "BrokenLink" (
    "id" SERIAL NOT NULL,
    "url" TEXT NOT NULL,
    "error" TEXT,
    "provider" TEXT,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BrokenLink_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "BrokenLink_url_idx" ON "BrokenLink"("url");

-- CreateIndex
CREATE INDEX "BrokenLink_provider_idx" ON "BrokenLink"("provider");

-- CreateIndex
CREATE INDEX "BrokenLink_timestamp_idx" ON "BrokenLink"("timestamp");
