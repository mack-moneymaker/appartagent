/**
 * Bien'ici scraper (React SPA)
 */

function buildSearchUrl(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const type = isRental ? 'location' : 'achat';
  
  // Bien'ici uses a JSON-encoded filter in the URL
  const filters = {
    filterType: isRental ? 'rent' : 'buy',
    propertyType: ['flat', 'house'],
    maxPrice: profile.max_budget || undefined,
    minPrice: profile.min_budget || undefined,
    minArea: profile.min_surface || undefined,
    maxArea: profile.max_surface || undefined,
    minRooms: profile.min_rooms || undefined,
    maxRooms: profile.max_rooms || undefined,
  };
  
  // Clean undefined
  Object.keys(filters).forEach(k => filters[k] === undefined && delete filters[k]);
  
  // Bien'ici search URL format
  const city = profile.city || 'Paris';
  const encoded = encodeURIComponent(JSON.stringify(filters));
  return `https://www.bienici.com/recherche/${type}/${city.toLowerCase().replace(/\s+/g, '-')}?filters=${encoded}`;
}

export async function scrapeBienIci(page, profile) {
  // Simpler approach: use the standard search URL
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const type = isRental ? 'location' : 'achat';
  const city = (profile.city || 'paris').toLowerCase().replace(/\s+/g, '-');
  
  let url = `https://www.bienici.com/recherche/${type}/${city}`;
  const params = new URLSearchParams();
  if (profile.max_budget) params.set('prix-max', profile.max_budget);
  if (profile.min_budget) params.set('prix-min', profile.min_budget);
  if (profile.min_surface) params.set('surface-min', profile.min_surface);
  if (profile.min_rooms) params.set('pieces-min', profile.min_rooms);
  
  const qs = params.toString();
  if (qs) url += `?${qs}`;
  
  console.log(`    URL: ${url}`);
  
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(4000 + Math.random() * 2000);
  
  // Wait for React to render results
  const selector = '[class*="searchResults"] a[href*="/annonce/"], [class*="ListItem"], article[class*="Result"]';
  
  try {
    await page.waitForSelector(selector, { timeout: 15000 });
  } catch {
    const content = await page.textContent('body');
    if (content.includes('Aucun résultat') || content.includes('pas de résultat')) {
      console.log('    No results found on Bien\'ici');
      return [];
    }
    throw new Error('Could not find listing cards on Bien\'ici - possibly blocked or SPA not loaded');
  }
  
  const listings = await page.evaluate(() => {
    const results = [];
    const links = document.querySelectorAll('a[href*="/annonce/"]');
    const seen = new Set();
    
    for (const link of links) {
      try {
        const href = link.getAttribute('href');
        const idMatch = href.match(/\/annonce\/([\w-]+)/);
        if (!idMatch || seen.has(idMatch[1])) continue;
        seen.add(idMatch[1]);
        
        const card = link.closest('article, [class*="ListItem"], [class*="Result"]') || link;
        
        const title = card.querySelector('[class*="Title"], h2, h3')?.textContent?.trim() || '';
        const priceText = card.querySelector('[class*="Price"], [class*="price"]')?.textContent?.trim() || '';
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || null;
        
        const locationText = card.querySelector('[class*="City"], [class*="city"], [class*="Location"]')?.textContent?.trim() || '';
        
        const fullText = card.textContent || '';
        const surfaceMatch = fullText.match(/(\d+)\s*m²/);
        const roomsMatch = fullText.match(/(\d+)\s*p(?:ièce|\.)/);
        
        const img = card.querySelector('img')?.getAttribute('src') || '';
        
        results.push({
          external_id: idMatch[1],
          title: title || `${surfaceMatch?.[0] || ''} ${roomsMatch?.[0] || ''} ${locationText}`.trim(),
          price,
          city: locationText,
          postal_code: locationText.match(/\d{5}/)?.[0] || null,
          surface: surfaceMatch ? parseFloat(surfaceMatch[1]) : null,
          rooms: roomsMatch ? parseInt(roomsMatch[1]) : null,
          url: `https://www.bienici.com${href}`,
          photos: img ? [img] : [],
        });
      } catch {}
    }
    
    return results;
  });
  
  return listings.map(l => ({
    ...l,
    platform: 'bienici',
    photos: JSON.stringify(l.photos || []),
  }));
}
