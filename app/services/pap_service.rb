# PAP Service (De Particulier à Particulier)
#
# PAP.fr — French platform for direct owner-to-renter listings (no agents)
#
# APPROACH: Web scraping (no known public API)
# - Search URL: https://www.pap.fr/annonce/location-appartement-paris-75-g439
# - URL structure: /annonce/location-{type}-{city}-{dept}-g{geo_id}
# - Pagination: ?page=2
#
# HTML STRUCTURE (as of 2024):
# - Listings in <div class="search-list-item">
# - Title: <a class="item-title">
# - Price: <span class="item-price">
# - Surface/rooms: <ul class="item-tags"> <li>
# - Photos: <img> within item carousel
# - Detail page: each listing links to /annonces/{id}
#
# SCRAPING NOTES:
# - Moderate anti-bot (basic rate limiting, no Cloudflare)
# - Respectful scraping possible with delays (2-3s between requests)
# - robots.txt allows /annonce/ paths
# - Consider Nokogiri + HTTParty for parsing
# - Geo IDs need to be mapped from city names
#
# LEGAL:
# - PAP has historically been more tolerant of scraping
# - Still, respect rate limits and Terms of Service
# - See GitHub issue #5 for GDPR compliance
#
class PapService
  BASE_URL = "https://www.pap.fr".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[PAP] Fetching listings for profile ##{@profile.id} — #{@profile.city}")
    # STUB: Would scrape PAP.fr
    # 1. Build search URL from profile criteria
    # 2. Fetch HTML with HTTParty
    # 3. Parse with Nokogiri
    # 4. Extract listing data
    # 5. Return normalized hashes
    []
  end

  private

  def search_url
    type = @profile.property_type || "appartement"
    city = @profile.city&.parameterize || "paris"
    "#{BASE_URL}/annonce/location-#{type}-#{city}"
  end

  def parse_listing(doc)
    {
      platform: "pap",
      external_id: doc.css(".item-title a").first&.[]("href")&.scan(/\d+/)&.first,
      title: doc.css(".item-title").text&.strip,
      price: doc.css(".item-price").text&.gsub(/[^\d]/, "")&.to_i,
      url: "#{BASE_URL}#{doc.css('.item-title a').first&.[]('href')}"
    }
  end
end
