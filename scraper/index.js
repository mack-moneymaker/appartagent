import 'dotenv/config';
import { chromium } from 'playwright';
import { scrapeLeBonCoin } from './platforms/leboncoin.js';
import { scrapePAP } from './platforms/pap.js';
import { scrapeBienIci } from './platforms/bienici.js';
import { scrapeSeLoger } from './platforms/seloger.js';
import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';

const API_URL = process.env.API_URL || 'https://appartagent-app.fly.dev';
const API_KEY = process.env.SCRAPER_API_KEY;

if (!API_KEY) {
  console.error('❌ SCRAPER_API_KEY is not set. Create a .env file (see .env.example)');
  process.exit(1);
}

const SCRAPERS = {
  leboncoin: scrapeLeBonCoin,
  pap: scrapePAP,
  bienici: scrapeBienIci,
  seloger: scrapeSeLoger,
};

const DEBUG_DIR = path.join(import.meta.dirname, 'debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

const CDP_PORT = 9222;
const CHROME_PROFILE_DIR = path.join(import.meta.dirname, '.chrome-profile');

async function fetchSearchProfiles() {
  const res = await fetch(`${API_URL}/api/search_profiles`, {
    headers: { 'Authorization': `Bearer ${API_KEY}` },
  });
  if (!res.ok) throw new Error(`Failed to fetch profiles: ${res.status} ${await res.text()}`);
  return res.json();
}

async function fetchPendingProfiles() {
  const res = await fetch(`${API_URL}/api/search_profiles/pending`, {
    headers: { 'Authorization': `Bearer ${API_KEY}` },
  });
  if (!res.ok) throw new Error(`Failed to fetch pending profiles: ${res.status} ${await res.text()}`);
  return res.json();
}

async function markProfileScraped(profileId) {
  const res = await fetch(`${API_URL}/api/search_profiles/${profileId}/scraped`, {
    method: 'PATCH',
    headers: { 'Authorization': `Bearer ${API_KEY}` },
  });
  if (!res.ok) console.error(`Failed to mark profile ${profileId} as scraped: ${res.status}`);
}

async function postListings(listings) {
  if (listings.length === 0) return { created: 0, updated: 0, errors: [] };
  const res = await fetch(`${API_URL}/api/listings/import`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ listings }),
  });
  if (!res.ok) throw new Error(`Failed to post listings: ${res.status} ${await res.text()}`);
  return res.json();
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

/**
 * Launch Chrome with CDP and connect via Playwright.
 * Using a real Chrome instance (not Playwright's bundled Chromium) avoids
 * most bot detection since no automation flags are injected.
 */
async function launchBrowserCDP() {
  fs.mkdirSync(CHROME_PROFILE_DIR, { recursive: true });

  // Check if Chrome is available
  const chromePath = process.platform === 'darwin'
    ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    : 'google-chrome-stable';

  // Kill any leftover CDP Chrome instances
  try {
    const { execSync } = await import('child_process');
    execSync(`pkill -f "remote-debugging-port=${CDP_PORT}"`, { stdio: 'ignore' });
    await sleep(1000);
  } catch {}

  const chromeProcess = spawn(chromePath, [
    `--remote-debugging-port=${CDP_PORT}`,
    `--user-data-dir=${CHROME_PROFILE_DIR}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--window-size=1920,1080',
    '--window-position=-9999,-9999', // Off-screen
    'about:blank',
  ], { stdio: 'ignore', detached: true });
  chromeProcess.unref();

  // Wait for CDP to be ready
  for (let i = 0; i < 30; i++) {
    await sleep(500);
    try {
      const res = await fetch(`http://127.0.0.1:${CDP_PORT}/json/version`);
      if (res.ok) {
        console.log('🌐 Chrome CDP ready');
        const browser = await chromium.connectOverCDP(`http://127.0.0.1:${CDP_PORT}`);
        return { browser, chromeProcess };
      }
    } catch {}
  }
  chromeProcess.kill();
  throw new Error('Chrome CDP did not start within 15s');
}

/**
 * Fallback: launch with Playwright's built-in browser (used for Bien'ici which works fine)
 */
async function launchBrowserPlaywright() {
  const browser = await chromium.launch({
    headless: false,
    args: ['--window-position=-9999,-9999', '--disable-blink-features=AutomationControlled'],
  });

  const context = await browser.newContext({
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
    viewport: { width: 1440, height: 900 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  });

  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
  });

  return { browser, context };
}

async function main() {
  console.log('🏠 AppartAgent Scraper starting...');
  console.log(`📡 API: ${API_URL}`);

  // Fetch pending profiles first (priority), then all active
  let pendingProfiles = [];
  let profiles;
  try {
    pendingProfiles = await fetchPendingProfiles();
    if (pendingProfiles.length > 0) {
      console.log(`🚀 Found ${pendingProfiles.length} pending profile(s) (priority)`);
    }
    profiles = await fetchSearchProfiles();
    console.log(`📋 Found ${profiles.length} active search profile(s)`);
  } catch (e) {
    console.error('❌ Could not fetch search profiles:', e.message);
    process.exit(1);
  }

  // Deduplicate: pending first, then remaining active
  const pendingIds = new Set(pendingProfiles.map(p => p.id));
  const remainingProfiles = profiles.filter(p => !pendingIds.has(p.id));
  profiles = [...pendingProfiles, ...remainingProfiles];

  if (profiles.length === 0) {
    console.log('⚠️  No active search profiles. Nothing to scrape.');
    return;
  }

  // Platforms that need CDP (anti-bot protection)
  const cdpPlatforms = new Set(['pap', 'seloger', 'leboncoin']);
  
  // Check which platforms we need
  const allPlatforms = new Set(profiles.flatMap(p => p.platforms));
  const needCDP = [...allPlatforms].some(p => cdpPlatforms.has(p));
  const needPlaywright = [...allPlatforms].some(p => !cdpPlatforms.has(p));

  let cdpBrowser = null, chromeProcess = null;
  let pwBrowser = null, pwContext = null;

  if (needCDP) {
    console.log('🌐 Launching Chrome via CDP (for protected sites)...');
    try {
      ({ browser: cdpBrowser, chromeProcess } = await launchBrowserCDP());
    } catch (e) {
      console.error('⚠️  CDP launch failed, falling back to Playwright for all:', e.message);
    }
  }

  if (needPlaywright || !cdpBrowser) {
    console.log('🌐 Launching Playwright browser...');
    ({ browser: pwBrowser, context: pwContext } = await launchBrowserPlaywright());
  }

  const allListings = [];
  const stats = {};

  for (const profile of profiles) {
    const isPending = pendingIds.has(profile.id);
    console.log(`\n🔍 Profile #${profile.id}: ${profile.city} ${profile.min_budget || '?'}–${profile.max_budget || '?'}€${isPending ? ' [PENDING]' : ''}`);

    for (const platform of profile.platforms) {
      const scraper = SCRAPERS[platform];
      if (!scraper) {
        console.log(`  ⚠️  No scraper for platform: ${platform}`);
        continue;
      }

      console.log(`  🔄 Scraping ${platform}...`);
      
      // Choose browser: CDP for protected sites, Playwright for others
      const useCDP = cdpPlatforms.has(platform) && cdpBrowser;
      let page;
      
      if (useCDP) {
        const ctx = cdpBrowser.contexts()[0];
        page = await ctx.newPage();
      } else {
        const ctx = pwContext || (await pwBrowser.newContext({
          locale: 'fr-FR',
          timezoneId: 'Europe/Paris',
          viewport: { width: 1440, height: 900 },
        }));
        page = await ctx.newPage();
      }

      try {
        const listings = await scraper(page, profile);
        console.log(`  ✅ ${platform}: ${listings.length} listing(s) found`);
        allListings.push(...listings);
        stats[platform] = (stats[platform] || 0) + listings.length;
      } catch (e) {
        console.error(`  ❌ ${platform} failed:`, e.message);
        // Save debug screenshot
        try {
          const screenshotPath = path.join(DEBUG_DIR, `${platform}-${Date.now()}.png`);
          await page.screenshot({ path: screenshotPath, fullPage: true });
          console.log(`  📸 Debug screenshot: ${screenshotPath}`);
        } catch {}
        stats[platform] = stats[platform] || 0;
      } finally {
        await page.close();
      }

      // Random delay between platforms
      await sleep(2000 + Math.random() * 3000);
    }

    // Mark profile as scraped if it was pending
    if (isPending) {
      try {
        await markProfileScraped(profile.id);
        console.log(`  ✅ Profile #${profile.id} marked as scraped`);
      } catch (e) {
        console.error(`  ⚠️  Failed to mark profile #${profile.id} as scraped:`, e.message);
      }
    }
  }

  // Cleanup
  if (cdpBrowser) await cdpBrowser.close();
  if (chromeProcess) {
    try {
      const { execSync } = await import('child_process');
      execSync(`pkill -f "remote-debugging-port=${CDP_PORT}"`, { stdio: 'ignore' });
    } catch {}
  }
  if (pwBrowser) await pwBrowser.close();

  // Deduplicate by platform + external_id
  const seen = new Set();
  const unique = allListings.filter(l => {
    const key = `${l.platform}:${l.external_id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  console.log(`\n📊 Total: ${unique.length} unique listing(s)`);
  Object.entries(stats).forEach(([p, c]) => console.log(`   ${p}: ${c}`));

  // Post to API
  if (unique.length > 0) {
    console.log('\n📤 Posting listings to API...');
    try {
      // Post in batches of 50
      for (let i = 0; i < unique.length; i += 50) {
        const batch = unique.slice(i, i + 50);
        const result = await postListings(batch);
        console.log(`   Batch ${Math.floor(i/50)+1}: ${result.created} created, ${result.updated} updated`);
        if (result.errors?.length > 0) {
          console.log(`   ⚠️  ${result.errors.length} error(s):`, result.errors.slice(0, 3));
        }
      }
    } catch (e) {
      console.error('❌ Failed to post listings:', e.message);
    }
  }

  console.log('\n✨ Done!');
}

main().catch(e => {
  console.error('💥 Fatal error:', e);
  process.exit(1);
});
