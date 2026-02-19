import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const DEBUG_DIR = path.join(import.meta.dirname, 'debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

const PROFILE_DIR = path.join(import.meta.dirname, '.browser-profile');

const platform = process.argv[2] || 'leboncoin';

const urls = {
  leboncoin: 'https://www.leboncoin.fr/recherche?category=10&locations=Saint-Etienne&price=min-800&sort=time&order=desc',
  pap: 'https://www.pap.fr/annonce/location-appartement-maison-saint-etienne?prix-max=800',
  seloger: 'https://www.seloger.com/list.htm?projects=1&types=1,2&natures=1,2,4&places=[{ci:420218}]&price=NaN/800&enterprise=0&qsVersion=1.0',
};

async function main() {
  const url = urls[platform];
  console.log(`Debugging ${platform} with persistent Chrome profile`);
  console.log(`URL: ${url}`);
  console.log(`Profile dir: ${PROFILE_DIR}`);

  const context = await chromium.launchPersistentContext(PROFILE_DIR, {
    channel: 'chrome',
    headless: false,
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-sandbox',
    ],
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
  });

  const page = context.pages()[0] || await context.newPage();

  // First visit homepage to build cookies
  const homepages = {
    leboncoin: 'https://www.leboncoin.fr',
    pap: 'https://www.pap.fr',
    seloger: 'https://www.seloger.com',
  };
  
  console.log('Visiting homepage first...');
  await page.goto(homepages[platform], { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(5000);
  
  let title = await page.title();
  console.log(`Homepage title: ${title}`);
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-persistent-home.png`) });

  // If there's a cookie consent, try to accept it
  try {
    const acceptBtn = await page.$('button:has-text("Accepter"), button:has-text("accepter"), #didomi-notice-agree-button, button[id*="accept"], button[id*="consent"]');
    if (acceptBtn) {
      console.log('Clicking cookie consent...');
      await acceptBtn.click();
      await page.waitForTimeout(2000);
    }
  } catch {}

  // Check for challenge
  const html = await page.content();
  const blocked = html.includes('captcha-delivery') || html.includes('cf-challenge') || 
                  title.includes('moment') || title.includes('Access Denied');
  
  if (blocked) {
    console.log('Still blocked on homepage, waiting 30s for challenge to resolve...');
    // Move mouse around
    for (let i = 0; i < 5; i++) {
      await page.mouse.move(200 + Math.random() * 600, 200 + Math.random() * 400);
      await page.waitForTimeout(1000 + Math.random() * 2000);
    }
    await page.waitForTimeout(20000);
    title = await page.title();
    console.log(`Title after wait: ${title}`);
    await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-persistent-home2.png`) });
  }

  // Now navigate to search
  console.log('Navigating to search...');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(8000);
  
  title = await page.title();
  console.log(`Search title: ${title}`);
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-persistent-search.png`), fullPage: true });
  
  const searchHtml = await page.content();
  fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-persistent.html`), searchHtml);
  
  const stillBlocked = searchHtml.includes('captcha-delivery') || searchHtml.includes('cf-challenge') ||
                       title.includes('moment') || title.includes('Access Denied');
  console.log(`Blocked on search: ${stillBlocked}`);

  if (!stillBlocked) {
    const info = await page.evaluate(() => {
      const allLinks = document.querySelectorAll('a');
      const adLinks = Array.from(allLinks).filter(a => a.href && (a.href.includes('/ad/') || a.href.includes('/annonce')));
      return {
        totalLinks: allLinks.length,
        adLinks: adLinks.length,
        sampleHrefs: adLinks.slice(0, 5).map(a => a.href),
        articles: document.querySelectorAll('article').length,
        h2s: Array.from(document.querySelectorAll('h2')).slice(0, 5).map(h => h.textContent.trim().substring(0, 100)),
        dataTestIds: Array.from(new Set(Array.from(document.querySelectorAll('[data-test-id]')).map(e => e.getAttribute('data-test-id')))).slice(0, 20),
        // First 500 chars of main content
        mainText: document.querySelector('main, #app, #root, body')?.textContent?.substring(0, 1000)?.trim(),
      };
    });
    console.log('DOM info:', JSON.stringify(info, null, 2));
  }

  await context.close();
  console.log('Done!');
}

main().catch(e => { console.error(e); process.exit(1); });
