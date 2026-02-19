import { chromium } from 'playwright';
import { execSync, spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

const DEBUG_DIR = path.join(import.meta.dirname, 'debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

const platform = process.argv[2] || 'leboncoin';

const urls = {
  leboncoin: 'https://www.leboncoin.fr/recherche?category=10&locations=Saint-Etienne&price=min-800&sort=time&order=desc',
  pap: 'https://www.pap.fr/annonce/location-appartement-maison-saint-etienne?prix-max=800',
  seloger: 'https://www.seloger.com/list.htm?projects=1&types=1,2&natures=1,2,4&places=[{ci:420218}]&price=NaN/800&enterprise=0&qsVersion=1.0',
};

const CDP_PORT = 9222;
const PROFILE_DIR = path.join(import.meta.dirname, '.chrome-cdp-profile');

async function main() {
  const url = urls[platform];
  console.log(`Debugging ${platform} via CDP`);

  // Kill any existing Chrome debug instances
  try { execSync('pkill -f "remote-debugging-port=9222"', { stdio: 'ignore' }); } catch {}
  await new Promise(r => setTimeout(r, 1000));

  // Launch Chrome manually with debugging port
  fs.mkdirSync(PROFILE_DIR, { recursive: true });
  const chromeProcess = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
    `--remote-debugging-port=${CDP_PORT}`,
    `--user-data-dir=${PROFILE_DIR}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-background-networking',
    '--window-size=1920,1080',
    'about:blank',
  ], { stdio: 'ignore', detached: true });
  chromeProcess.unref();

  // Wait for Chrome to start
  console.log('Waiting for Chrome to start...');
  await new Promise(r => setTimeout(r, 3000));

  // Connect via CDP
  console.log('Connecting via CDP...');
  const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
  const context = browser.contexts()[0];
  const page = context.pages()[0] || await context.newPage();

  // Navigate to homepage first
  const homepages = { leboncoin: 'https://www.leboncoin.fr', pap: 'https://www.pap.fr', seloger: 'https://www.seloger.com' };
  console.log('Visiting homepage...');
  await page.goto(homepages[platform], { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(5000);

  let title = await page.title();
  console.log(`Homepage title: ${title}`);
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-cdp-home.png`) });

  // Accept cookies if prompted
  try {
    const btn = await page.$('button:has-text("Accepter"), button:has-text("accepter"), #didomi-notice-agree-button, button[id*="accept"]');
    if (btn) { await btn.click(); await page.waitForTimeout(2000); }
  } catch {}

  const homeHtml = await page.content();
  const homeBlocked = homeHtml.includes('captcha-delivery') || homeHtml.includes('cf-challenge');
  console.log(`Homepage blocked: ${homeBlocked}`);

  if (homeBlocked) {
    console.log('Waiting 15s for challenge...');
    await page.waitForTimeout(15000);
    title = await page.title();
    console.log(`After wait: ${title}`);
    await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-cdp-home2.png`) });
  }

  // Navigate to search
  console.log('Navigating to search...');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(8000);
  
  title = await page.title();
  console.log(`Search title: ${title}`);
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-cdp-search.png`), fullPage: true });
  
  const searchHtml = await page.content();
  fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-cdp.html`), searchHtml);
  
  const blocked = searchHtml.includes('captcha-delivery') || searchHtml.includes('cf-challenge') ||
                  title.includes('moment') || title.includes('Access Denied');
  console.log(`Search blocked: ${blocked}`);

  if (!blocked) {
    const info = await page.evaluate(() => {
      const adLinks = Array.from(document.querySelectorAll('a')).filter(a => a.href && (a.href.includes('/ad/') || a.href.includes('/annonce')));
      return {
        adLinks: adLinks.length,
        sampleHrefs: adLinks.slice(0, 5).map(a => a.href),
        articles: document.querySelectorAll('article').length,
        dataTestIds: Array.from(new Set(Array.from(document.querySelectorAll('[data-test-id]')).map(e => e.getAttribute('data-test-id')))).slice(0, 20),
        h2s: Array.from(document.querySelectorAll('h2')).slice(0, 5).map(h => h.textContent.trim().substring(0, 100)),
      };
    });
    console.log('DOM:', JSON.stringify(info, null, 2));
  }

  await browser.close();
  try { execSync('pkill -f "remote-debugging-port=9222"', { stdio: 'ignore' }); } catch {}
  console.log('Done!');
}

main().catch(async e => { 
  console.error(e); 
  try { execSync('pkill -f "remote-debugging-port=9222"', { stdio: 'ignore' }); } catch {}
  process.exit(1); 
});
