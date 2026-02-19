import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const DEBUG_DIR = path.join(import.meta.dirname, 'debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

async function main() {
  const platform = process.argv[2] || 'leboncoin';
  
  const urls = {
    leboncoin: 'https://www.leboncoin.fr/recherche?category=10&locations=Saint-Etienne&price=min-800&sort=time&order=desc',
    pap: 'https://www.pap.fr/annonce/location-appartement-maison-saint-etienne?prix-max=800',
    seloger: 'https://www.seloger.com/list.htm?projects=1&types=1,2&natures=1,2,4&places=[{ci:420218}]&price=NaN/800&enterprise=0&qsVersion=1.0',
  };

  const url = urls[platform];
  if (!url) { console.log('Unknown platform:', platform); return; }

  console.log(`Debugging ${platform}: ${url}`);

  const browser = await chromium.launch({
    channel: 'chrome',
    headless: false,
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-sandbox',
      '--window-size=1920,1080',
    ],
  });

  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  });

  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
    delete navigator.__proto__.webdriver;
    window.chrome = { runtime: {} };
    Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
    Object.defineProperty(navigator, 'languages', { get: () => ['fr-FR', 'fr', 'en-US', 'en'] });
  });

  const page = await context.newPage();

  // For SeLoger, go to homepage first
  if (platform === 'seloger') {
    console.log('Navigating to SeLoger homepage first...');
    await page.goto('https://www.seloger.com', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(5000);
    await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-homepage.png`), fullPage: true });
    console.log('Homepage screenshot saved');
  }

  console.log('Navigating to search page...');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  
  // Wait for page to load
  console.log('Waiting 5s for page to settle...');
  await page.waitForTimeout(5000);

  // Screenshot
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-page.png`), fullPage: true });
  console.log(`Screenshot saved to debug/${platform}-page.png`);

  // Save HTML
  const html = await page.content();
  fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-page.html`), html);
  console.log(`HTML saved to debug/${platform}-page.html`);

  // Save title
  const title = await page.title();
  console.log(`Page title: ${title}`);

  // For Cloudflare/Akamai - wait longer and retry
  if (title.includes('moment') || title.includes('Access') || title.includes('Robot') || title.includes('Checking')) {
    console.log('Challenge detected, waiting 20s...');
    await page.waitForTimeout(20000);
    await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-after-wait.png`), fullPage: true });
    const html2 = await page.content();
    fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-after-wait.html`), html2);
    const title2 = await page.title();
    console.log(`Title after wait: ${title2}`);
  }

  // For LeBonCoin, dump some DOM info
  if (platform === 'leboncoin') {
    const info = await page.evaluate(() => {
      // Find all links with /ad/ in href
      const adLinks = document.querySelectorAll('a[href*="/ad/"]');
      // Find elements with data attributes
      const dataTestEls = document.querySelectorAll('[data-test-id]');
      const dataQaEls = document.querySelectorAll('[data-qa-id]');
      // Find all articles
      const articles = document.querySelectorAll('article');
      // Check for specific LBC structures
      const listItems = document.querySelectorAll('[data-test-id="ad"]');
      
      return {
        adLinks: adLinks.length,
        adLinkSamples: Array.from(adLinks).slice(0, 3).map(a => ({ href: a.href, classes: a.className, outerHTML: a.outerHTML.substring(0, 500) })),
        dataTestIds: Array.from(dataTestEls).slice(0, 10).map(e => e.getAttribute('data-test-id')),
        dataQaIds: Array.from(dataQaEls).slice(0, 10).map(e => e.getAttribute('data-qa-id')),
        articles: articles.length,
        listItems: listItems.length,
        // Get text from first few article-like elements
        bodyClasses: document.body.className,
      };
    });
    console.log('DOM info:', JSON.stringify(info, null, 2));
  }

  await browser.close();
  console.log('Done!');
}

main().catch(e => { console.error(e); process.exit(1); });
