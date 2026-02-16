# SeLoger Service
#
# SeLoger.com — major French real estate platform (part of Aviv Group / Axel Springer)
#
# API (reverse-engineered from mobile app):
# - Base URL: https://api-seloger.svc.groupe-seloger.com
# - Search: GET /api/v1/listings
# - Auth: API key in headers (rotates with app versions)
# - Headers:
#   - x-api-key: required
#   - User-Agent: SeLoger-mobile
#
# Query parameters:
# - transactionType: 1 (rent)
# - realtyTypes: 1 (apartment), 2 (house)
# - localityIds: SeLoger locality ID (not postal code — need mapping)
# - maximumPrice, minimumPrice
# - minimumSurface, maximumSurface
# - minimumRooms, maximumRooms
# - furnished: true/false
# - sortBy: publicationDate-desc
#
# NOTES:
# - SeLoger has a public search API for partners (requires registration)
# - Their anti-bot protection is moderate (Akamai)
# - Locality IDs need to be resolved from city names via their autocomplete API
# - Autocomplete: GET /api/v1/localities?searchTerm={city}
#
class SelogerService
  BASE_URL = "https://api-seloger.svc.groupe-seloger.com".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[SeLoger] Fetching listings for profile ##{@profile.id} — #{@profile.city}")
    # STUB: Would call SeLoger API
    []
  end

  private

  def build_params
    {
      transactionType: 1,
      maximumPrice: @profile.max_budget,
      minimumPrice: @profile.min_budget,
      minimumSurface: @profile.min_surface,
      maximumSurface: @profile.max_surface,
      minimumRooms: @profile.min_rooms,
      maximumRooms: @profile.max_rooms,
      sortBy: "publicationDate-desc"
    }.compact
  end

  def parse_listing(item)
    {
      platform: "seloger",
      external_id: item["id"].to_s,
      title: item["title"],
      description: item["description"],
      price: item["price"],
      surface: item["surface"],
      rooms: item["rooms"],
      city: item["city"],
      postal_code: item["zipcode"],
      url: item["permalink"],
      latitude: item["latitude"],
      longitude: item["longitude"],
      photos: item["photos"]&.map { |p| p["url"] },
      dpe_rating: item["energyPerformanceDiagnostic"],
      published_at: item["publicationDate"]
    }
  end
end
