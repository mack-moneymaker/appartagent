import { chromium } from 'playwright';
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

async function main() {
  const url = urls[platform];
  console.log(`Debugging ${platform} with system Chrome: ${url}`);

  const browser = await chromium.launch({
    channel: 'chrome',
    headless: false,
    args: [
      '--disable-blink-features=AutomationControlled',
      '--disable-features=IsolateOrigins,site-per-process',
      '--no-sandbox',
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
    window.chrome = { runtime: {}, loadTimes: function(){}, csi: function(){} };
    Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
    Object.defineProperty(navigator, 'languages', { get: () => ['fr-FR', 'fr', 'en-US', 'en'] });
    // Override permissions
    const originalQuery = window.navigator.permissions.query;
    window.navigator.permissions.query = (parameters) =>
      parameters.name === 'notifications'
        ? Promise.resolve({ state: Notification.permission })
        : originalQuery(parameters);
  });

  const page = await context.newPage();

  // Navigate
  console.log('Navigating...');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });

  // Take initial screenshot
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-chrome-1.png`), fullPage: true });
  console.log('Screenshot 1 saved');

  // Check for challenges
  const title = await page.title();
  console.log(`Title: ${title}`);
  const html = await page.content();
  
  const hasDatadome = html.includes('datadome') || html.includes('captcha-delivery');
  const hasCloudflare = title.includes('moment') || html.includes('cf-challenge');
  const hasAkamai = title.includes('Access Denied') || html.includes('_abck');
  
  console.log(`DataDome: ${hasDatadome}, Cloudflare: ${hasCloudflare}, Akamai: ${hasAkamai}`);

  if (hasDatadome || hasCloudflare || hasAkamai) {
    console.log('Challenge detected, waiting 25s...');
    // Mouse movements to appear human
    await page.mouse.move(500, 300);
    await page.waitForTimeout(2000);
    await page.mouse.move(700, 400);
    await page.waitForTimeout(2000);
    await page.mouse.move(300, 500);
    await page.waitForTimeout(21000);
    
    await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-chrome-2.png`), fullPage: true });
    const title2 = await page.title();
    console.log(`Title after wait: ${title2}`);
    
    const html2 = await page.content();
    fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-chrome.html`), html2);
    
    // Check if challenge resolved
    const stillBlocked = html2.includes('datadome') || html2.includes('captcha-delivery') || 
                          html2.includes('cf-challenge') || title2.includes('moment') ||
                          title2.includes('Access Denied');
    console.log(`Still blocked: ${stillBlocked}`);
    
    if (!stillBlocked) {
      // Dump DOM info
      const info = await page.evaluate(() => {
        return {
          links: document.querySelectorAll('a').length,
          articles: document.querySelectorAll('article').length,
          h2s: Array.from(document.querySelectorAll('h2')).slice(0, 5).map(h => h.textContent.trim().substring(0, 80)),
        };
      });
      console.log('DOM:', JSON.stringify(info, null, 2));
    }
  } else {
    fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-chrome.html`), html);
    // Dump DOM info
    const info = await page.evaluate(() => {
      return {
        links: document.querySelectorAll('a').length,
        articles: document.querySelectorAll('article').length,
        h2s: Array.from(document.querySelectorAll('h2')).slice(0, 5).map(h => h.textContent.trim().substring(0, 80)),
        dataTestIds: Array.from(document.querySelectorAll('[data-test-id]')).slice(0, 10).map(e => e.getAttribute('data-test-id')),
      };
    });
    console.log('DOM:', JSON.stringify(info, null, 2));
  }

  await browser.close();
  console.log('Done!');
}

main().catch(e => { console.error(e); process.exit(1); });
