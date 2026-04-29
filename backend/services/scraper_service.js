const { chromium } = require('playwright');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  static NAV_TIMEOUT_MS = 45000;
  static UA_WINDOWS_CHROME =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static detectProvider(targetUrl) {
    const url = String(targetUrl || '').toLowerCase();
    if (url.includes('vidsrc.win')) return 'vidsrcwin';
    if (url.includes('dood') || url.includes('/e/') || url.includes('doodstream')) return 'doodstream';
    if (url.includes('streamtape')) return 'streamtape';
    if (url.includes('mixdrop')) return 'mixdrop';
    if (url.includes('supervideo') || url.includes('fembed')) return 'supervideo';
    if (url.includes('vsembed') || url.includes('vidsrc')) return 'vidsrc';
    return 'unknown';
  }

  static isValidHttpUrl(value) {
    try {
      const parsed = new URL(value);
      return parsed.protocol === 'http:' || parsed.protocol === 'https:';
    } catch (_) {
      return false;
    }
  }

  static buildCandidates(targetUrl) {
    const raw = String(targetUrl || '').trim();
    if (this.isValidHttpUrl(raw)) return [raw];

    // Soporte híbrido TMDB: "tmdb:550" o "550"
    const tmdbMatch = raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d{2,10})$/);
    if (!tmdbMatch) return [];

    const id = tmdbMatch[1];
    return [
      `https://vidsrc.win/embed/movie/${id}`,
      `https://vidsrc.win/embed/tv/${id}/1/1`
    ];
  }

  static isIgnoredTraffic(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    return (
      url.includes('audio') ||
      url.includes('trailer') ||
      url.includes('advert') ||
      url.includes('doubleclick') ||
      url.includes('googlesyndication') ||
      url.includes('googleads')
    );
  }

  static isStreamCandidate(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    if (this.isIgnoredTraffic(url)) return false;
    return url.includes('.m3u8') || url.includes('.mp4') || url.includes('master.m3u8');
  }

  static isEmbedProvider(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    return url.includes('/embed/') || url.includes('vidsrc.win/embed/');
  }

  static async runGhostClicks(page) {
    await page.mouse.click(400, 300);
    await page.waitForTimeout(500);
    await page.mouse.click(420, 320);
    await page.waitForTimeout(500);
    await page.mouse.click(380, 280);
    await page.evaluate(() => window.scrollBy(0, 240));
  }

  static async extractFromSingleUrl(targetUrl) {
    let browser;
    const provider = this.detectProvider(targetUrl);

    try {
      browser = await chromium.launch({
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--single-process'
        ]
      });

      const refererOrigin = new URL(targetUrl).origin;
      const context = await browser.newContext({
        userAgent: this.UA_WINDOWS_CHROME,
        extraHTTPHeaders: {
          Referer: `${refererOrigin}/`
        }
      });
      const page = await context.newPage();
      page.setDefaultNavigationTimeout(this.NAV_TIMEOUT_MS);
      page.setDefaultTimeout(this.NAV_TIMEOUT_MS);

      const streamPromise = new Promise((resolve) => {
        page.on('request', (req) => {
          const reqUrl = req.url();
          if (this.isStreamCandidate(reqUrl)) resolve(reqUrl);
        });
        page.on('response', (res) => {
          const resUrl = res.url();
          if (this.isStreamCandidate(resUrl)) resolve(resUrl);
        });
      });

      await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: this.NAV_TIMEOUT_MS });

      if (this.isEmbedProvider(targetUrl) || provider === 'vidsrcwin') {
        await this.runGhostClicks(page);
      }

      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error(`Timeout: no se detectó stream en ${this.NAV_TIMEOUT_MS / 1000}s`)), this.NAV_TIMEOUT_MS)
      );

      const streamUrl = await Promise.race([streamPromise, timeoutPromise]);
      return streamUrl || null;
    } finally {
      if (browser) {
        await browser.close();
      }
    }
  }

  static async extractStreamUrl(targetUrl) {
    const startTime = Date.now();
    let success = false;
    let streamUrlResult = null;
    let errorMessage = null;

    try {
      const candidates = this.buildCandidates(targetUrl);
      if (!candidates.length) {
        throw new Error('targetUrl inválido: usa URL http(s) o ID TMDB');
      }

      for (const candidate of candidates) {
        try {
          const stream = await this.extractFromSingleUrl(candidate);
          if (stream) {
            success = true;
            streamUrlResult = stream;
            break;
          }
        } catch (candidateError) {
          errorMessage = candidateError.message;
          await this.logBrokenLink(candidate, candidateError, this.detectProvider(candidate));
        }
      }

      return streamUrlResult;
    } catch (error) {
      errorMessage = error.message;
      await this.logBrokenLink(String(targetUrl || ''), error, this.detectProvider(String(targetUrl || '')));
      return null;
    } finally {
      await this.saveLog(
        String(targetUrl || ''),
        success,
        streamUrlResult,
        errorMessage,
        Date.now() - startTime
      );
    }
  }

  static async saveLog(url, success, result, error, duration) {
    try {
      await prisma.scrapeLog.create({
        data: {
          targetUrl: url,
          success,
          streamUrl: result,
          error,
          duration
        }
      });
    } catch (e) {
      console.error('Error BD Log:', e.message);
    }
  }

  static async logBrokenLink(targetUrl, error, provider) {
    try {
      await prisma.brokenLink.create({
        data: {
          url: targetUrl,
          error: error.message,
          provider,
          timestamp: new Date()
        }
      });
    } catch (e) {
      console.error('Error BD BrokenLink:', e.message);
    }
  }
}

module.exports = VideoScraper;
