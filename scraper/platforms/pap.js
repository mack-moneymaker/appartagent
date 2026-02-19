/**
 * PAP.fr scraper
 * DOM structure (from debug/pap-cdp2.html):
 *   .search-list-item-alt > .item-body > a.item-title
 *   .item-price, .item-tags li, .item-description
 *   Cookie consent: custom sd-cmp with "Tout accepter" or "Continuer sans accepter"
 */

function buildSearchUrl(profile) {
  const isRental = (profile.transaction_type || 'rental') === 'rental';
  const type = isRental ? 'location' : 'vente';
  
  let url = `https://www.pap.fr/annonce/${type}-appartement-maison`;
  
  if (profile.city) {
    url += `-${profile.city.toLowerCase().replace(/\s+/g, '-').replace(/[éèê]/g, 'e').replace(/[àâ]/g, 'a')}`;
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
  await page.waitForTimeout(3000 + Math.random() * 2000);
  
  // Check for Cloudflare block
  const title = await page.title();
  if (title.includes('Just a moment') || title.includes('Cloudflare')) {
    console.log('    ⚠️  Cloudflare challenge, waiting 20s...');
    await page.waitForTimeout(20000);
    const newTitle = await page.title();
    if (newTitle.includes('Just a moment') || newTitle.includes('Cloudflare')) {
      throw new Error('Cloudflare challenge did not resolve');
    }
  }
  
  // Dismiss cookie consent - PAP uses custom sd-cmp consent framework
  try {
    // Try multiple strategies for cookie consent
    const consentSelectors = [
      'span:has-text("Tout accepter")',
      'span:has-text("Continuer sans accepter")',
      'button:has-text("Tout accepter")',
      'button:has-text("Continuer sans accepter")',
      '#didomi-notice-agree-button',
      'button:has-text("Accepter")',
    ];
    
    for (const sel of consentSelectors) {
      try {
        const btn = await page.$(sel);
        if (btn) {
          const visible = await btn.isVisible();
          if (visible) {
            console.log(`    🍪 Clicking consent: ${sel}`);
            await btn.click();
            await page.waitForTimeout(1500);
            break;
          }
        }
      } catch {}
    }
    
    // Fallback: use evaluate to find and click consent button by text
    await page.evaluate(() => {
      const spans = document.querySelectorAll('span, button');
      for (const el of spans) {
        const text = el.textContent?.trim();
        if (text === 'Tout accepter' || text === 'Continuer sans accepter') {
          el.click();
          break;
        }
      }
    });
    await page.waitForTimeout(1000);
  } catch {}
  
  // Wait for listings - try both selectors
  try {
    await page.waitForSelector('.search-list-item-alt, .item-body', { timeout: 15000 });
  } catch {
    const content = await page.textContent('body').catch(() => '');
    if (content.includes('Aucune annonce') || content.includes('0 résultat') || content.includes('pas de résultat')) {
      console.log('    No results found on PAP');
      return [];
    }
    throw new Error('Could not find listing cards on PAP - possibly blocked');
  }
  
  const listings = await page.evaluate(() => {
    const results = [];
    // Use .search-list-item-alt as container (15 found in debug dump)
    const items = document.querySelectorAll('.search-list-item-alt');
    
    for (const item of items) {
      try {
        const body = item.querySelector('.item-body');
        if (!body) continue;
        
        const link = body.querySelector('a.item-title');
        if (!link) continue;
        
        const href = link.getAttribute('href');
        if (!href || !href.includes('/annonces/')) continue;
        
        const idMatch = href.match(/r(\d+)$/);
        if (!idMatch) continue;
        
        // Price
        const priceEl = body.querySelector('.item-price');
        const priceText = priceEl?.textContent?.trim() || '';
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || null;
        
        // Tags (rooms, surface)
        const tags = Array.from(body.querySelectorAll('.item-tags li')).map(li => li.textContent.trim());
        const fullText = tags.join(' ');
        const surfaceMatch = fullText.match(/(\d+)\s*m²/);
        const roomsMatch = fullText.match(/(\d+)\s*pièce/);
        
        // Description
        const desc = body.querySelector('.item-description')?.textContent?.trim() || '';
        
        // Extract city from link text — find the part that looks like "City (XXXXX)"
        const linkText = link.textContent || '';
        const cityMatch = linkText.match(/([A-ZÀ-Ü][a-zà-ü'-]+(?:\s+[A-ZÀ-Ü][a-zà-ü'-]+)*)\s*\((\d{5})\)/);
        const city = cityMatch ? cityMatch[1].trim() : '';
        const postalCode = cityMatch ? cityMatch[2] : (linkText.match(/(\d{5})/) || [])[1] || null;
        
        // Photos - look in the item container for thumbnails
        const photos = [];
        item.querySelectorAll('.item-thumb-link img, .owl-carousel img, .owl-item img, img').forEach(img => {
          const src = img.getAttribute('src') || img.getAttribute('data-src');
          if (src && src.startsWith('http') && !photos.includes(src) && !src.includes('logo') && !src.includes('icon')) {
            photos.push(src);
          }
        });
        
        // Build clean title
        const titleParts = [city || 'Logement', postalCode ? `(${postalCode})` : '', tags.join(', ')].filter(Boolean);
        
        results.push({
          external_id: idMatch[1],
          title: titleParts.join(' ') || desc.substring(0, 80),
          price,
          city,
          postal_code: postalCode,
          surface: surfaceMatch ? parseFloat(surfaceMatch[1]) : null,
          rooms: roomsMatch ? parseInt(roomsMatch[1]) : null,
          url: href.startsWith('http') ? href : `https://www.pap.fr${href}`,
          photos,
        });
      } catch {}
    }
    
    return results;
  });
  
  console.log(`    📊 Extracted ${listings.length} listings from PAP DOM`);
  
  return listings.map(l => ({
    ...l,
    platform: 'pap',
    photos: JSON.stringify(l.photos || []),
  }));
}
