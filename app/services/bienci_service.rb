# Bien'ici Service
#
# Bien-ici.com — French real estate aggregator (backed by FNAIM)
#
# API (reverse-engineered):
# - Base URL: https://www.bien-ici.com/realEstateAds
# - Method: POST with JSON body
# - No auth required for search (public API)
# - Returns JSON with detailed listing data
#
# Search payload:
# {
#   "realEstateTypes": ["flat"],
#   "filters": {
#     "filterType": "rent",
#     "maxPrice": 1500,
#     "minPrice": 500,
#     "minArea": 25,
#     "maxArea": 80,
#     "minRooms": 1,
#     "maxRooms": 3
#   },
#   "zoneIdsByTypes": {
#     "zoneIds": ["-7444"]  # Zone IDs for cities/neighborhoods
#   },
#   "size": 24,
#   "from": 0,
#   "sortBy": "publicationDate",
#   "sortOrder": "desc"
# }
#
# NOTES:
# - Relatively open API, no aggressive anti-bot
# - Zone IDs can be obtained from autocomplete endpoint
# - Autocomplete: GET /realEstateAds/zoneIdsByTypes?text={city}
# - Good source for DPE ratings and detailed property info
# - Photos are high quality with direct URLs
#
class BienciService
  BASE_URL = "https://www.bien-ici.com".freeze
  SEARCH_ENDPOINT = "/realEstateAds".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[Bien'ici] Fetching listings for profile ##{@profile.id} — #{@profile.city}")
    # TODO: Implement Bien'ici API integration. Requires:
    # - Zone ID resolution via autocomplete endpoint
    # - Relatively open API, good candidate for next implementation
    []
  end

  private

  def build_payload
    {
      realEstateTypes: [map_property_type],
      filters: {
        filterType: "rent",
        maxPrice: @profile.max_budget,
        minPrice: @profile.min_budget,
        minArea: @profile.min_surface,
        maxArea: @profile.max_surface,
        minRooms: @profile.min_rooms,
        maxRooms: @profile.max_rooms
      }.compact,
      size: 24,
      from: 0,
      sortBy: "publicationDate",
      sortOrder: "desc"
    }
  end

  def map_property_type
    case @profile.property_type
    when "apartment", "studio" then "flat"
    when "house" then "house"
    else "flat"
    end
  end

  def parse_listing(item)
    {
      platform: "bienici",
      external_id: item["id"].to_s,
      title: item["title"],
      description: item["description"],
      price: item["price"],
      surface: item["area"],
      rooms: item["roomsQuantity"],
      city: item["city"],
      postal_code: item["postalCode"],
      neighborhood: item["district"],
      address: item["address"],
      latitude: item.dig("blurInfo", "position", "lat"),
      longitude: item.dig("blurInfo", "position", "lng"),
      photos: item["photos"]&.map { |p| p["url"] },
      dpe_rating: item["energyClassification"],
      furnished: item["isFurnished"],
      published_at: item["publicationDate"],
      url: "#{BASE_URL}/annonce/#{item['id']}"
    }
  end
end
