ALTER TABLE "Content"
ADD COLUMN "subtitle_url" TEXT,
ADD COLUMN "subtitle_language" TEXT DEFAULT 'es-419',
ADD COLUMN "subtitle_label" TEXT DEFAULT 'Espanol Latino';

ALTER TABLE "Episode"
ADD COLUMN "subtitle_url" TEXT,
ADD COLUMN "subtitle_language" TEXT DEFAULT 'es-419',
ADD COLUMN "subtitle_label" TEXT DEFAULT 'Espanol Latino';
