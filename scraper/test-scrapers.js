import { chromium } from 'playwright';
import { spawn, execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { scrapePAP } from './platforms/pap.js';
import { scrapeSeLoger } from './platforms/seloger.js';
import { scrapeBienIci } from './platforms/bienici.js';
import { scrapeLeBonCoin } from './platforms/leboncoin.js';

const DEBUG_DIR = path.join(import.meta.dirname, 'debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

const CDP_PORT = 9222;
const PROFILE_DIR = path.join(import.meta.dirname, '.chrome-profile');

const profile = {
  id: 1,
  city: 'Saint-Etienne',
  max_budget: 800,
  transaction_type: 'rental',
  platforms: ['bienici', 'pap', 'seloger', 'leboncoin'],
};

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const targetPlatform = process.argv[2] || 'all';
  
  // Launch Chrome with CDP
  fs.mkdirSync(PROFILE_DIR, { recursive: true });
  try { execSync(`pkill -f "remote-debugging-port=${CDP_PORT}"`, { stdio: 'ignore' }); } catch {}
  await sleep(1000);

  const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const chromeProcess = spawn(chromePath, [
    `--remote-debugging-port=${CDP_PORT}`,
    `--user-data-dir=${PROFILE_DIR}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--window-size=1920,1080',
    'about:blank',
  ], { stdio: 'ignore', detached: true });
  chromeProcess.unref();

  // Wait for CDP
  for (let i = 0; i < 20; i++) {
    await sleep(500);
    try {
      const res = await fetch(`http://127.0.0.1:${CDP_PORT}/json/version`);
      if (res.ok) break;
    } catch {}
  }

  console.log('Chrome CDP ready');
  const browser = await chromium.connectOverCDP(`http://127.0.0.1:${CDP_PORT}`);

  const scrapers = {
    pap: scrapePAP,
    seloger: scrapeSeLoger,
    leboncoin: scrapeLeBonCoin,
  };

  // For bienici, use Playwright since it works without CDP
  const platforms = targetPlatform === 'all' ? ['pap', 'seloger', 'leboncoin'] : [targetPlatform];

  for (const p of platforms) {
    if (p === 'bienici') continue; // Test separately
    const scraper = scrapers[p];
    if (!scraper) { console.log(`Unknown: ${p}`); continue; }

    console.log(`\n=== Testing ${p} ===`);
    const ctx = browser.contexts()[0];
    const page = await ctx.newPage();

    try {
      const listings = await scraper(page, profile);
      console.log(`✅ ${p}: ${listings.length} listings found`);
      if (listings.length > 0) {
        console.log('Sample:', JSON.stringify(listings[0], null, 2));
      }
    } catch (e) {
      console.error(`❌ ${p} failed:`, e.message);
      try {
        await page.screenshot({ path: path.join(DEBUG_DIR, `${p}-test-fail.png`), fullPage: true });
        console.log(`📸 Screenshot saved to debug/${p}-test-fail.png`);
      } catch {}
    } finally {
      await page.close();
    }
    
    await sleep(2000);
  }

  await browser.close();
  try { execSync(`pkill -f "remote-debugging-port=${CDP_PORT}"`, { stdio: 'ignore' }); } catch {}
  console.log('\nDone!');
}

main().catch(e => { console.error(e); process.exit(1); });
