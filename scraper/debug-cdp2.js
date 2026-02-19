import { chromium } from 'playwright';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

const DEBUG_DIR = path.join(import.meta.dirname, 'debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

const platform = process.argv[2] || 'all';

const urls = {
  leboncoin: 'https://www.leboncoin.fr/recherche?category=10&locations=Saint-Etienne&price=min-800&sort=time&order=desc',
  pap: 'https://www.pap.fr/annonce/location-appartement-maison-saint-etienne?prix-max=800',
  seloger: 'https://www.seloger.com/list.htm?projects=1&types=1,2&natures=1,2,4&places=[{ci:420218}]&price=NaN/800&enterprise=0&qsVersion=1.0',
};

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function launchChrome() {
  const profileDir = '/tmp/appartagent-chrome-profile';
  fs.mkdirSync(profileDir, { recursive: true });
  
  const proc = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
    '--remote-debugging-port=9222',
    `--user-data-dir=${profileDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--window-size=1920,1080',
    'about:blank',
  ], { stdio: ['ignore', 'pipe', 'pipe'] });
  
  // Wait for CDP to be ready
  for (let i = 0; i < 20; i++) {
    await sleep(500);
    try {
      const res = await fetch('http://127.0.0.1:9222/json/version');
      if (res.ok) {
        console.log('Chrome CDP ready');
        return proc;
      }
    } catch {}
  }
  throw new Error('Chrome CDP did not start');
}

async function testPlatform(browser, name, url) {
  console.log(`\n=== Testing ${name} ===`);
  console.log(`URL: ${url}`);
  
  const context = browser.contexts()[0];
  const page = await context.newPage();
  
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await sleep(8000);
    
    const title = await page.title();
    console.log(`Title: ${title}`);
    
    await page.screenshot({ path: path.join(DEBUG_DIR, `${name}-cdp2.png`), fullPage: true });
    
    const html = await page.content();
    fs.writeFileSync(path.join(DEBUG_DIR, `${name}-cdp2.html`), html);
    
    const hasDatadome = html.includes('captcha-delivery') || html.includes('datadome');
    const hasCloudflare = html.includes('cf-challenge') || title.includes('moment') || title.includes('Checking');
    const hasAkamai = title.includes('Access Denied');
    
    console.log(`DataDome: ${hasDatadome}, Cloudflare: ${hasCloudflare}, Akamai: ${hasAkamai}`);
    
    if (!hasDatadome && !hasCloudflare && !hasAkamai) {
      const info = await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('a'));
        const adLinks = links.filter(a => a.href && (a.href.includes('/ad/') || a.href.includes('/annonce')));
        return {
          totalLinks: links.length,
          adLinks: adLinks.length,
          sampleHrefs: adLinks.slice(0, 3).map(a => a.href),
          bodyText: document.body?.textContent?.substring(0, 500),
        };
      });
      console.log(`Links: ${info.totalLinks}, Ad links: ${info.adLinks}`);
      if (info.sampleHrefs.length) console.log('Sample:', info.sampleHrefs);
      return true;
    }
    return false;
  } finally {
    await page.close();
  }
}

async function main() {
  const chromeProc = await launchChrome();
  
  try {
    const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
    
    const platforms = platform === 'all' ? Object.keys(urls) : [platform];
    
    for (const p of platforms) {
      const ok = await testPlatform(browser, p, urls[p]);
      console.log(`${p}: ${ok ? '✅ ACCESSIBLE' : '❌ BLOCKED'}`);
    }
    
    await browser.close();
  } finally {
    chromeProc.kill();
  }
}

main().catch(e => { console.error(e); process.exit(1); });
