/**
 * SeLoger scraper
 * Primary: try API. Fallback: try mobile site. Last resort: skip.
 */

function buildSearchUrl(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const base = 'https://www.seloger.com/list.htm';
  
  const params = new URLSearchParams();
  params.set('projects', isRental ? '1' : '2');
  params.set('types', '1,2');
  params.set('natures', '1,2,4');
  
  if (profile.city) {
    const inseeMap = {
      'saint-etienne': '420218',
      'paris': '750056',
      'lyon': '690123',
      'marseille': '130055',
      'toulouse': '310555',
      'bordeaux': '330063',
      'nantes': '440109',
      'lille': '590350',
    };
    const cityKey = profile.city.toLowerCase().replace(/\s+/g, '-').replace(/[éèê]/g, 'e');
    const insee = inseeMap[cityKey] || profile.city;
    params.set('places', `[{"inseeCodes":[${insee}]}]`);
  }
  
  if (profile.max_budget) params.set('price', `NaN/${profile.max_budget}`);
  if (profile.min_surface) params.set('surface', `${profile.min_surface}/NaN`);
  if (profile.min_rooms) params.set('rooms', `${profile.min_rooms}/NaN`);
  params.set('enterprise', '0');
  params.set('qsVersion', '1.0');
  
  return `${base}?${params.toString()}`;
}

function buildApiUrl(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const params = new URLSearchParams();
  params.set('transactionType', isRental ? '1' : '2');
  params.set('realtyTypes', '1,2');
  if (profile.max_budget) params.set('maximumPrice', profile.max_budget);
  if (profile.min_surface) params.set('minimumLivingArea', profile.min_surface);
  if (profile.min_rooms) params.set('minimumRoomCount', profile.min_rooms);
  params.set('pageSize', '25');
  params.set('pageIndex', '1');
  
  // Try to get city code
  const inseeMap = {
    'saint-etienne': '420218',
    'paris': '750056',
    'lyon': '690123',
  };
  const cityKey = (profile.city || '').toLowerCase().replace(/\s+/g, '-').replace(/[éèê]/g, 'e');
  if (inseeMap[cityKey]) {
    params.set('inseeCodes', inseeMap[cityKey]);
  }
  
  return `https://api-seloger.svc.group/api/v1/listings?${params.toString()}`;
}

async function tryApi(profile) {
  console.log('    Trying SeLoger API...');
  const url = buildApiUrl(profile);
  
  const headers = {
    'Accept': 'application/json',
    'User-Agent': 'SeLoger/15.0.0 (iPhone; iOS 17.0)',
    'Accept-Language': 'fr-FR,fr;q=0.9',
  };
  
  const res = await fetch(url, { headers });
  if (!res.ok) {
    throw new Error(`API returned ${res.status}`);
  }
  
  const data = await res.json();
  const items = data.items || data.results || data.listings || [];
  
  return items.map(item => {
    const photos = (item.photos || item.images || []).map(p => p.url || p).filter(Boolean);
    return {
      external_id: String(item.id || item.listingId || ''),
      platform: 'seloger',
      title: item.title || `${item.roomCount || '?'}p ${item.livingArea || '?'}m² ${item.city || ''}`,
      price: item.price || item.rentPrice || null,
      city: item.city || '',
      postal_code: item.zipCode || item.postalCode || null,
      surface: item.livingArea || item.surface || null,
      rooms: item.roomCount || item.rooms || null,
      url: item.permalink || item.url || `https://www.seloger.com/annonces/${item.id}.htm`,
      photos: JSON.stringify(photos),
    };
  });
}

async function tryBrowser(page, profile) {
  const url = buildSearchUrl(profile);
  console.log(`    Trying SeLoger browser: ${url}`);
  
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(5000 + Math.random() * 3000);
  
  const title = await page.title();
  if (title.includes('Access Denied') || title.includes('Robot') || title.includes('moment') || title.includes('Error')) {
    throw new Error(`SeLoger blocked: title="${title}"`);
  }
  
  // Accept cookies
  try {
    const btn = await page.$('#didomi-notice-agree-button, button:has-text("Accepter"), button:has-text("Tout accepter")');
    if (btn) { await btn.click(); await page.waitForTimeout(1000); }
  } catch {}
  
  const cardSelector = '[data-testid="sl.explore.card-container"]';
  await page.waitForSelector(cardSelector, { timeout: 15000 });
  
  const listings = await page.evaluate(() => {
    const results = [];
    const cards = document.querySelectorAll('[data-testid="sl.explore.card-container"]');
    const seen = new Set();
    
    for (const card of cards) {
      try {
        const link = card.querySelector('[data-testid="sl.explore.coveringLink"]');
        if (!link) continue;
        const href = link.getAttribute('href');
        if (!href || !href.includes('/annonces/')) continue;
        const idMatch = href.match(/\/(\d+)\.htm/);
        if (!idMatch || seen.has(idMatch[1])) continue;
        seen.add(idMatch[1]);
        
        const priceEl = card.querySelector('[data-test="sl.price-label"]');
        const priceText = priceEl?.textContent?.trim() || '';
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || null;
        
        const fullText = card.textContent || '';
        const surfaceMatch = fullText.match(/(\d+)\s*m²/);
        const roomsMatch = fullText.match(/(\d+)\s*pièce/);
        
        const photos = [];
        card.querySelectorAll('img[src*="seloger.com"]').forEach(img => {
          const src = img.getAttribute('src');
          if (src && !photos.includes(src)) photos.push(src.replace(/\/crop\/\d+x\d+\//, '/crop/800x600/'));
        });
        
        results.push({
          external_id: idMatch[1],
          title: `${roomsMatch?.[0] || ''} ${surfaceMatch?.[0] || ''}`.trim(),
          price,
          city: '',
          postal_code: null,
          surface: surfaceMatch ? parseFloat(surfaceMatch[1]) : null,
          rooms: roomsMatch ? parseInt(roomsMatch[1]) : null,
          url: href.startsWith('http') ? href : `https://www.seloger.com${href}`,
          photos,
        });
      } catch {}
    }
    return results;
  });
  
  return listings.map(l => ({ ...l, platform: 'seloger', photos: JSON.stringify(l.photos || []) }));
}

export async function scrapeSeLoger(page, profile) {
  // Strategy 1: API
  try {
    const results = await tryApi(profile);
    if (results.length > 0) {
      console.log(`    ✅ SeLoger API: ${results.length} listings`);
      return results;
    }
    console.log('    API returned 0 results, trying browser...');
  } catch (e) {
    console.log(`    API failed: ${e.message}, trying browser...`);
  }
  
  // Strategy 2: Browser
  try {
    const results = await tryBrowser(page, profile);
    console.log(`    ✅ SeLoger browser: ${results.length} listings`);
    return results;
  } catch (e) {
    console.log(`    ❌ SeLoger browser failed: ${e.message}`);
    console.log('    ⚠️  Skipping SeLoger — blocked on all approaches');
    return [];
  }
}
