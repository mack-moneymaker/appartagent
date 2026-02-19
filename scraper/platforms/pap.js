/**
 * PAP.fr scraper
 */

function buildSearchUrl(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const type = isRental ? 'location' : 'vente';
  
  let url = `https://www.pap.fr/annonce/${type}-appartement-maison`;
  
  // City
  if (profile.city) {
    url += `-${profile.city.toLowerCase().replace(/\s+/g, '-')}`;
  }
  
  const params = new URLSearchParams();
  
  if (profile.min_budget) params.set('prix-min', profile.min_budget);
  if (profile.max_budget) params.set('prix-max', profile.max_budget);
  if (profile.min_surface) params.set('surface-min', profile.min_surface);
  if (profile.max_surface) params.set('surface-max', profile.max_surface);
  if (profile.min_rooms) params.set('nb-pieces-min', profile.min_rooms);
  if (profile.max_rooms) params.set('nb-pieces-max', profile.max_rooms);
  
  const qs = params.toString();
  return qs ? `${url}?${qs}` : url;
}

export async function scrapePAP(page, profile) {
  const url = buildSearchUrl(profile);
  console.log(`    URL: ${url}`);
  
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  
  // Wait for Cloudflare challenge to resolve
  await page.waitForTimeout(4000 + Math.random() * 2000);
  
  // Check for Cloudflare block
  const title = await page.title();
  if (title.includes('Just a moment') || title.includes('Cloudflare')) {
    console.log('    ⚠️  Cloudflare challenge, waiting 15s...');
    await page.waitForTimeout(15000);
  }
  
  // Wait for listings
  const selector = '.search-list-content .search-list-item, .search-results-list .search-results-item, article.item';
  
  try {
    await page.waitForSelector(selector, { timeout: 15000 });
  } catch {
    const content = await page.textContent('body');
    if (content.includes('Aucune annonce') || content.includes('0 résultat')) {
      console.log('    No results found on PAP');
      return [];
    }
    throw new Error('Could not find listing cards on PAP - possibly blocked');
  }
  
  const listings = await page.evaluate(() => {
    const results = [];
    const items = document.querySelectorAll('.search-list-content .search-list-item, article.item, [class*="search-results"] a[href*="/annonce"]');
    
    for (const item of items) {
      try {
        const link = item.querySelector('a[href*="/annonce"]') || item.closest('a[href*="/annonce"]');
        if (!link) continue;
        
        const href = link.getAttribute('href');
        const idMatch = href.match(/annonce[s]?[/-].*?-?(\w+)$/);
        if (!idMatch) continue;
        
        const title = item.querySelector('h2, .item-title, [class*="title"]')?.textContent?.trim() || '';
        const priceText = item.querySelector('[class*="price"], .item-price')?.textContent?.trim() || '';
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || null;
        
        const locationText = item.querySelector('[class*="location"], .item-description, [class*="city"]')?.textContent?.trim() || '';
        
        const fullText = item.textContent || '';
        const surfaceMatch = fullText.match(/(\d+)\s*m²/);
        const roomsMatch = fullText.match(/(\d+)\s*p(?:ièce|\.)/);
        
        const img = item.querySelector('img')?.getAttribute('src') || '';
        
        results.push({
          external_id: idMatch[1],
          title,
          price,
          city: locationText,
          postal_code: locationText.match(/\d{5}/)?.[0] || null,
          surface: surfaceMatch ? parseFloat(surfaceMatch[1]) : null,
          rooms: roomsMatch ? parseInt(roomsMatch[1]) : null,
          url: href.startsWith('http') ? href : `https://www.pap.fr${href}`,
          photos: img ? [img] : [],
        });
      } catch {}
    }
    
    return results;
  });
  
  return listings.map(l => ({
    ...l,
    platform: 'pap',
    photos: JSON.stringify(l.photos || []),
  }));
}
