/**
 * SeLoger scraper
 * SeLoger has aggressive Akamai bot protection - we try but gracefully skip if blocked
 */

function buildSearchUrl(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const base = isRental
    ? 'https://www.seloger.com/list.htm'
    : 'https://www.seloger.com/list.htm';
  
  const params = new URLSearchParams();
  params.set('projects', isRental ? '1' : '2'); // 1=location, 2=achat
  params.set('types', '1,2'); // 1=appart, 2=maison
  params.set('natures', '1,2,4'); // 1=ancien, 2=neuf, 4=viager
  
  if (profile.city) {
    // SeLoger uses location codes, fallback to text search
    params.set('places', `[{ci:${profile.city}}]`);
  }
  
  if (profile.max_budget) params.set('price', `${profile.min_budget || 'NaN'}/${profile.max_budget}`);
  if (profile.min_surface) params.set('surface', `${profile.min_surface}/NaN`);
  if (profile.min_rooms) params.set('rooms', `${profile.min_rooms}/NaN`);
  
  params.set('enterprise', '0');
  params.set('qsVersion', '1.0');
  
  return `${base}?${params.toString()}`;
}

export async function scrapeSeLoger(page, profile) {
  const url = buildSearchUrl(profile);
  console.log(`    URL: ${url}`);
  
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  } catch (e) {
    throw new Error(`SeLoger navigation failed: ${e.message}`);
  }
  
  // Wait for potential Akamai challenge
  await page.waitForTimeout(5000 + Math.random() * 3000);
  
  // Check if blocked
  const title = await page.title();
  if (title.includes('Access Denied') || title.includes('Robot')) {
    throw new Error('SeLoger blocked by Akamai');
  }
  
  // Wait for listings
  const selector = '[class*="ListContent"] a[href*="/annonces/"], [data-testid*="card"], article[class*="Card"]';
  
  try {
    await page.waitForSelector(selector, { timeout: 15000 });
  } catch {
    const content = await page.textContent('body');
    if (content.includes('Aucun résultat') || content.includes('Aucune annonce')) {
      console.log('    No results found on SeLoger');
      return [];
    }
    throw new Error('Could not find listing cards on SeLoger - possibly blocked');
  }
  
  const listings = await page.evaluate(() => {
    const results = [];
    const cards = document.querySelectorAll('a[href*="/annonces/"], [data-testid*="card"], article[class*="Card"]');
    const seen = new Set();
    
    for (const card of cards) {
      try {
        const link = card.tagName === 'A' ? card : card.querySelector('a[href*="/annonces/"]');
        if (!link) continue;
        
        const href = link.getAttribute('href');
        const idMatch = href.match(/\/(\d+)\.htm/);
        if (!idMatch || seen.has(idMatch[1])) continue;
        seen.add(idMatch[1]);
        
        const container = card.closest('article, [class*="Card"]') || card;
        
        const title = container.querySelector('[class*="Title"], h2, h3')?.textContent?.trim() || '';
        const priceText = container.querySelector('[class*="Price"], [class*="price"], [data-testid*="price"]')?.textContent?.trim() || '';
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || null;
        
        const locationText = container.querySelector('[class*="City"], [class*="city"], [class*="Location"]')?.textContent?.trim() || '';
        
        const fullText = container.textContent || '';
        const surfaceMatch = fullText.match(/(\d+)\s*m²/);
        const roomsMatch = fullText.match(/(\d+)\s*p(?:ièce|\.)/);
        
        const img = container.querySelector('img')?.getAttribute('src') || '';
        
        results.push({
          external_id: idMatch[1],
          title,
          price,
          city: locationText,
          postal_code: locationText.match(/\d{5}/)?.[0] || null,
          surface: surfaceMatch ? parseFloat(surfaceMatch[1]) : null,
          rooms: roomsMatch ? parseInt(roomsMatch[1]) : null,
          url: href.startsWith('http') ? href : `https://www.seloger.com${href}`,
          photos: img ? [img] : [],
        });
      } catch {}
    }
    
    return results;
  });
  
  return listings.map(l => ({
    ...l,
    platform: 'seloger',
    photos: JSON.stringify(l.photos || []),
  }));
}
