/**
 * LeBonCoin scraper
 * Uses search URL with query params for filters
 */

function buildSearchUrl(profile) {
  const base = 'https://www.leboncoin.fr/recherche';
  const params = new URLSearchParams();
  
  // Category: 10 = locations, 9 = ventes immobilières
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  params.set('category', isRental ? '10' : '9');
  
  // Location
  if (profile.city) {
    params.set('locations', profile.city);
  }
  
  // Price
  if (profile.min_budget || profile.max_budget) {
    params.set('price', `${profile.min_budget || 'min'}-${profile.max_budget || 'max'}`);
  }
  
  // Surface
  if (profile.min_surface || profile.max_surface) {
    params.set('square', `${profile.min_surface || 'min'}-${profile.max_surface || 'max'}`);
  }
  
  // Rooms
  if (profile.min_rooms || profile.max_rooms) {
    params.set('rooms', `${profile.min_rooms || 'min'}-${profile.max_rooms || 'max'}`);
  }
  
  // Furnished
  if (profile.furnished === true) {
    params.set('furnished', '1');
  }
  
  params.set('sort', 'time');
  params.set('order', 'desc');
  
  return `${base}?${params.toString()}`;
}

export async function scrapeLeBonCoin(page, profile) {
  const url = buildSearchUrl(profile);
  console.log(`    URL: ${url}`);
  
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  
  // Wait for potential Datadome challenge to resolve (real Chrome usually passes)
  await page.waitForTimeout(3000 + Math.random() * 2000);
  
  // Check if we got blocked
  const blocked = await page.$('iframe[src*="datadome"]');
  if (blocked) {
    console.log('    ⚠️  Datadome challenge detected, waiting 10s...');
    await page.waitForTimeout(10000);
  }
  
  // Wait for listing cards - try multiple selectors
  const listingSelector = '[data-test-id="adListCard"], [data-qa-id="aditem_container"], a[href*="/ad/"]';
  
  try {
    await page.waitForSelector(listingSelector, { timeout: 15000 });
  } catch {
    // Maybe no results or still blocked
    const content = await page.textContent('body');
    if (content.includes('Aucune annonce') || content.includes('0 résultat')) {
      console.log('    No results found on LeBonCoin');
      return [];
    }
    throw new Error('Could not find listing cards - possibly blocked');
  }
  
  // Extract listings from the page
  const listings = await page.evaluate(() => {
    const results = [];
    
    // Try to find listing links
    const cards = document.querySelectorAll('a[data-test-id="adListCard"], a[href*="/ad/locations/"], a[href*="/ad/ventes_immobilieres/"]');
    
    for (const card of cards) {
      try {
        const href = card.getAttribute('href');
        if (!href || !href.includes('/ad/')) continue;
        
        const fullUrl = href.startsWith('http') ? href : `https://www.leboncoin.fr${href}`;
        
        // Extract ID from URL
        const idMatch = href.match(/\/(\d+)\.htm/);
        if (!idMatch) continue;
        
        const title = card.querySelector('[data-test-id="adTitle"], h2, p[data-qa-id="aditem_title"]')?.textContent?.trim() || '';
        const priceText = card.querySelector('[data-test-id="adPrice"], [data-qa-id="aditem_price"], span[aria-label*="prix"]')?.textContent?.trim() || '';
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || null;
        
        const locationEl = card.querySelector('[data-test-id="adLocation"], [data-qa-id="aditem_location"], p[aria-label*="Localisation"]');
        const locationText = locationEl?.textContent?.trim() || '';
        
        const img = card.querySelector('img')?.getAttribute('src') || '';
        
        // Try to extract surface and rooms from the card text
        const fullText = card.textContent || '';
        const surfaceMatch = fullText.match(/(\d+)\s*m²/);
        const roomsMatch = fullText.match(/(\d+)\s*p(?:ièce|\.)/);
        
        results.push({
          external_id: idMatch[1],
          title,
          price,
          city: locationText.split(' ').slice(0, -1).join(' ') || locationText,
          postal_code: locationText.match(/\d{5}/)?.[0] || null,
          surface: surfaceMatch ? parseFloat(surfaceMatch[1]) : null,
          rooms: roomsMatch ? parseInt(roomsMatch[1]) : null,
          url: fullUrl,
          photos: img ? [img] : [],
        });
      } catch {}
    }
    
    return results;
  });
  
  return listings.map(l => ({
    ...l,
    platform: 'leboncoin',
    photos: JSON.stringify(l.photos || []),
  }));
}
