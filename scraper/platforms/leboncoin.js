/**
 * LeBonCoin scraper — API approach
 * Browser automation triggers Datadome captcha, so we use their mobile API directly.
 */

const USER_AGENTS = [
  'LBC;Android;15.2.0;Pixel 8',
  'LBC;Android;14.0.0;SM-S911B',
  'LBC;iOS;15.1.0;iPhone14,2',
];

function buildApiPayload(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  
  const payload = {
    limit: 35,
    offset: 0,
    filters: {
      category: { id: isRental ? '10' : '9' },
      enums: {},
      ranges: {},
      location: {},
    },
    sort_by: 'time',
    sort_order: 'desc',
  };
  
  // Location
  if (profile.city) {
    payload.filters.location.locations = [
      { locationType: 'city', label: profile.city }
    ];
  }
  
  // Price range
  if (profile.min_budget || profile.max_budget) {
    payload.filters.ranges.price = {};
    if (profile.min_budget) payload.filters.ranges.price.min = profile.min_budget;
    if (profile.max_budget) payload.filters.ranges.price.max = profile.max_budget;
  }
  
  // Surface
  if (profile.min_surface || profile.max_surface) {
    payload.filters.ranges.square = {};
    if (profile.min_surface) payload.filters.ranges.square.min = profile.min_surface;
    if (profile.max_surface) payload.filters.ranges.square.max = profile.max_surface;
  }
  
  // Rooms
  if (profile.min_rooms || profile.max_rooms) {
    payload.filters.ranges.rooms = {};
    if (profile.min_rooms) payload.filters.ranges.rooms.min = profile.min_rooms;
    if (profile.max_rooms) payload.filters.ranges.rooms.max = profile.max_rooms;
  }
  
  // Furnished
  if (profile.furnished === true) {
    payload.filters.enums.furnished = ['1'];
  }
  
  return payload;
}

export async function scrapeLeBonCoin(_page, profile) {
  // _page is unused — we do direct HTTP requests instead of browser automation
  const payload = buildApiPayload(profile);
  
  console.log(`    Using LeBonCoin mobile API approach`);
  
  // Try different configurations
  const configs = [
    { api_key: 'ba0c2dad52b3ec', ua: USER_AGENTS[0] },
    { api_key: 'ba0c2dad52b3ec', ua: USER_AGENTS[1] },
    { api_key: undefined, ua: USER_AGENTS[2] },
    { api_key: 'ba0c2dad52b3ec', ua: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36' },
  ];
  
  let data = null;
  
  for (const config of configs) {
    try {
      const headers = {
        'Content-Type': 'application/json',
        'User-Agent': config.ua,
        'Accept': 'application/json',
        'Accept-Language': 'fr-FR,fr;q=0.9',
      };
      if (config.api_key) {
        headers['api_key'] = config.api_key;
      }
      
      console.log(`    Trying API with UA: ${config.ua.substring(0, 30)}...`);
      
      const res = await fetch('https://api.leboncoin.fr/finder/search', {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      });
      
      if (res.ok) {
        data = await res.json();
        console.log(`    ✅ API responded OK`);
        break;
      } else {
        const status = res.status;
        const text = await res.text().catch(() => '');
        console.log(`    ⚠️  API returned ${status}: ${text.substring(0, 100)}`);
        
        if (status === 403 || status === 429) {
          // Blocked, try next config
          continue;
        }
        // Other error, might still try next
        continue;
      }
    } catch (e) {
      console.log(`    ⚠️  API request failed: ${e.message}`);
      continue;
    }
  }
  
  if (!data) {
    throw new Error('LeBonCoin API blocked on all attempts');
  }
  
  const ads = data.ads || data.results || [];
  console.log(`    📊 API returned ${ads.length} ads`);
  
  const listings = [];
  
  for (const ad of ads) {
    try {
      const id = String(ad.list_id || ad.id || '');
      if (!id) continue;
      
      // Extract attributes
      const attrs = {};
      if (ad.attributes) {
        for (const attr of ad.attributes) {
          attrs[attr.key] = attr.value;
        }
      }
      
      const price = ad.price?.[0] || parseInt(attrs.price) || null;
      const surface = parseInt(attrs.square) || null;
      const rooms = parseInt(attrs.rooms) || null;
      
      // Photos
      const photos = [];
      if (ad.images?.urls) {
        photos.push(...ad.images.urls);
      } else if (ad.images?.urls_large) {
        photos.push(...ad.images.urls_large);
      } else if (ad.images?.thumb_url) {
        photos.push(ad.images.thumb_url);
      }
      
      // Location
      const loc = ad.location || {};
      const city = loc.city || '';
      const postalCode = loc.zipcode || loc.postal_code || '';
      
      listings.push({
        external_id: id,
        platform: 'leboncoin',
        title: ad.subject || ad.title || `${rooms || '?'}p ${surface || '?'}m² ${city}`,
        price,
        city,
        postal_code: postalCode,
        surface,
        rooms,
        url: ad.url || `https://www.leboncoin.fr/ad/locations/${id}`,
        photos: JSON.stringify(photos),
      });
    } catch {}
  }
  
  return listings;
}
