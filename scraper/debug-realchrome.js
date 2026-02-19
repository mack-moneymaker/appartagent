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

async function main() {
  const url = urls[platform];
  console.log(`Debugging ${platform} with REAL Chrome profile`);

  // Kill Chrome first
  try { execSync('pkill -f "Google Chrome"', { stdio: 'ignore' }); } catch {}
  await new Promise(r => setTimeout(r, 2000));

  // Launch Chrome with the real user profile and debugging port
  const realProfile = path.join(process.env.HOME, 'Library/Application Support/Google/Chrome');
  const chromeProcess = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
    '--remote-debugging-port=9222',
    `--user-data-dir=${realProfile}`,
    '--no-first-run',
    'about:blank',
  ], { stdio: 'ignore', detached: true });
  chromeProcess.unref();

  console.log('Waiting for Chrome to start...');
  await new Promise(r => setTimeout(r, 4000));

  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0];
  const page = context.pages()[0] || await context.newPage();

  console.log('Navigating to search...');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(8000);
  
  const title = await page.title();
  console.log(`Title: ${title}`);
  await page.screenshot({ path: path.join(DEBUG_DIR, `${platform}-real-search.png`), fullPage: true });
  
  const html = await page.content();
  fs.writeFileSync(path.join(DEBUG_DIR, `${platform}-real.html`), html);
  
  const blocked = html.includes('captcha-delivery') || html.includes('cf-challenge') ||
                  title.includes('moment') || title.includes('Access Denied');
  console.log(`Blocked: ${blocked}`);

  if (!blocked) {
    const info = await page.evaluate(() => {
      const adLinks = Array.from(document.querySelectorAll('a')).filter(a => a.href && (a.href.includes('/ad/') || a.href.includes('/annonce')));
      return {
        adLinks: adLinks.length,
        sampleHrefs: adLinks.slice(0, 5).map(a => a.href),
        h2s: Array.from(document.querySelectorAll('h2')).slice(0, 5).map(h => h.textContent.trim().substring(0, 100)),
        dataTestIds: Array.from(new Set(Array.from(document.querySelectorAll('[data-test-id]')).map(e => e.getAttribute('data-test-id')))).slice(0, 20),
      };
    });
    console.log('DOM:', JSON.stringify(info, null, 2));
  }

  await browser.close();
  console.log('Done!');
}

main().catch(async e => { 
  console.error(e); 
  process.exit(1); 
});
