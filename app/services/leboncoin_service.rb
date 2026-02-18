# LeBonCoin Service
#
# LeBonCoin is the largest French classifieds platform. Their web interface
# is heavily protected against scraping (Datadome, Cloudflare).
#
# MOBILE API (reverse-engineered):
# - Base URL: https://api.leboncoin.fr/finder/search
# - Method: POST with JSON body
# - Required headers:
#   - api_key: "ba0c2dad52b3ec" (changes periodically, extracted from mobile app)
#   - User-Agent: "LBC;Android;{version};{device}" (must match current app version)
# - Auth: Bearer token from /api/oauth/v1/token (anonymous or authenticated)
#
# Search payload structure:
# {
#   "limit": 35,
#   "limit_alu": 3,
#   "filters": {
#     "category": { "id": "10" },           # 10 = locations (rentals)
#     "enums": {
#       "ad_type": ["offer"],
#       "real_estate_type": ["1","2"],       # 1=maison, 2=appartement
#       "furnished": ["1"]                    # 1=meublé
#     },
#     "location": {
#       "city_zipcodes": [{"zipcode": "75011"}],
#       "locations": [{"locationType": "city", "label": "Paris"}]
#     },
#     "ranges": {
#       "price": { "min": 800, "max": 1500 },
#       "square": { "min": 25, "max": 60 },
#       "rooms": { "min": 1, "max": 3 }
#     }
#   },
#   "sort_by": "time",
#   "sort_order": "desc"
# }
#
# RATE LIMITS:
# - ~100 requests/hour per IP estimated
# - Token expires every ~1h
# - Aggressive fingerprinting on mobile API too
#
# ANTI-SCRAPING:
# - Datadome on web (virtually impossible to bypass reliably)
# - Mobile API requires valid app signature
# - IP rotation recommended (residential proxies)
# - Consider: mobile app MITM proxy approach
#
# TODO: See GitHub issue #1 for research strategy
#
class LeboncoinService
  BASE_URL = "https://api.leboncoin.fr".freeze
  SEARCH_ENDPOINT = "/finder/search".freeze
  CATEGORY_RENTAL = "10".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  # Fetch new listings matching the search profile
  # Returns array of listing attributes hashes
  def fetch_listings
    # STUB: In production, this would:
    # 1. Obtain/refresh auth token
    # 2. Build search payload from @profile
    # 3. POST to search endpoint
    # 4. Parse response and return normalized listing data
    Rails.logger.info("[LeBonCoin] Fetching listings for profile ##{@profile.id} — #{@profile.city}")

    # TODO: Implement LeBonCoin scraping. Requires:
    # - Residential proxy rotation (Datadome protection)
    # - Valid mobile app API key (rotates with versions)
    # - Token refresh logic
    # See GitHub issue #1 for research strategy
    []
  end

  private

  def build_payload
    {
      limit: 35,
      filters: {
        category: { id: CATEGORY_RENTAL },
        location: {
          city_zipcodes: [{ zipcode: @profile.city }],
        },
        ranges: {
          price: { min: @profile.min_budget, max: @profile.max_budget }.compact,
          square: { min: @profile.min_surface, max: @profile.max_surface }.compact,
          rooms: { min: @profile.min_rooms, max: @profile.max_rooms }.compact
        }.reject { |_, v| v.empty? }
      },
      sort_by: "time",
      sort_order: "desc"
    }
  end

  def parse_listing(item)
    {
      platform: "leboncoin",
      external_id: item["list_id"].to_s,
      title: item["subject"],
      description: item["body"],
      price: item.dig("price", 0),
      url: "https://www.leboncoin.fr/locations/#{item['list_id']}.htm",
      city: item.dig("location", "city"),
      postal_code: item.dig("location", "zipcode"),
      published_at: item["first_publication_date"]
    }
  end
end
