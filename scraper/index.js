import 'dotenv/config';
import { chromium } from 'playwright';
import { scrapeLeBonCoin } from './platforms/leboncoin.js';
import { scrapePAP } from './platforms/pap.js';
import { scrapeBienIci } from './platforms/bienici.js';
import { scrapeSeLoger } from './platforms/seloger.js';
import fs from 'fs';
import path from 'path';

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

async function fetchSearchProfiles() {
  const res = await fetch(`${API_URL}/api/search_profiles`, {
    headers: { 'Authorization': `Bearer ${API_KEY}` },
  });
  if (!res.ok) throw new Error(`Failed to fetch profiles: ${res.status} ${await res.text()}`);
  return res.json();
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

async function main() {
  console.log('🏠 AppartAgent Scraper starting...');
  console.log(`📡 API: ${API_URL}`);

  // Fetch search profiles
  let profiles;
  try {
    profiles = await fetchSearchProfiles();
    console.log(`📋 Found ${profiles.length} active search profile(s)`);
  } catch (e) {
    console.error('❌ Could not fetch search profiles:', e.message);
    process.exit(1);
  }

  if (profiles.length === 0) {
    console.log('⚠️  No active search profiles. Nothing to scrape.');
    return;
  }

  // Launch browser
  console.log('🌐 Launching browser...');
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

  // Remove webdriver flag
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
  });

  const allListings = [];
  const stats = {};

  for (const profile of profiles) {
    console.log(`\n🔍 Profile #${profile.id}: ${profile.city} ${profile.min_budget || '?'}–${profile.max_budget || '?'}€`);

    for (const platform of profile.platforms) {
      const scraper = SCRAPERS[platform];
      if (!scraper) {
        console.log(`  ⚠️  No scraper for platform: ${platform}`);
        continue;
      }

      console.log(`  🔄 Scraping ${platform}...`);
      const page = await context.newPage();

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
  }

  await browser.close();

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
