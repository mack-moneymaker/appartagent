# SeLoger Service
#
# SeLoger.com — heavily protected by Akamai.
# Tries mobile API first, falls back gracefully.
# This is the least reliable scraper — expected to fail sometimes.
#
class SelogerService
  SEARCH_URL = "https://api-seloger.svc.groupe-seloger.com/api/v1/listings".freeze
  AUTOCOMPLETE_URL = "https://api-seloger.svc.groupe-seloger.com/api/v1/localities".freeze
  USER_AGENT = "SeLoger/14.5.0 (iPhone; iOS 17.2; Scale/3.00)".freeze

  # Hardcoded locality IDs for major cities
  LOCALITY_IDS = {
    "paris" => "250",
    "lyon" => "69123",
    "marseille" => "13055",
    "bordeaux" => "33063",
    "toulouse" => "31555",
    "nantes" => "44109",
    "lille" => "59350",
    "montpellier" => "34172",
    "nice" => "6088"
  }.freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[SeLoger] Fetching listings for profile ##{@profile.id} — #{@profile.city}")

    locality_id = resolve_locality_id
    unless locality_id
      Rails.logger.warn("[SeLoger] Could not resolve locality ID for #{@profile.city}, skipping")
      return []
    end

    params = build_params(locality_id)
    response = HTTParty.get(
      SEARCH_URL,
      query: params,
      headers: request_headers,
      timeout: 20
    )

    unless response.success?
      Rails.logger.warn("[SeLoger] HTTP #{response.code} — Akamai likely blocking. Skipping.")
      return []
    end

    data = response.parsed_response
    items = data.is_a?(Hash) ? (data["items"] || data["listings"] || []) : []

    listings = items.filter_map { |item| parse_listing(item) }
    Rails.logger.info("[SeLoger] Found #{listings.size} listings")
    listings
  rescue HTTParty::Error, Timeout::Error, SocketError, JSON::ParserError => e
    Rails.logger.warn("[SeLoger] Fetch failed (expected — Akamai protection): #{e.class}: #{e.message}")
    []
  end

  private

  def resolve_locality_id
    city_key = @profile.city&.downcase&.strip&.gsub(/\s+/, "-") || "paris"
    LOCALITY_IDS[city_key.split("-").first]
  end

  def build_params(locality_id)
    {
      transactionType: 1,
      realtyTypes: map_property_type,
      localityIds: locality_id,
      maximumPrice: @profile.max_budget,
      minimumPrice: @profile.min_budget,
      minimumSurface: @profile.min_surface,
      maximumSurface: @profile.max_surface,
      minimumRooms: @profile.min_rooms,
      maximumRooms: @profile.max_rooms,
      furnished: @profile.furnished ? true : nil,
      sortBy: "publicationDate-desc",
      pageSize: 25
    }.compact
  end

  def request_headers
    {
      "User-Agent" => USER_AGENT,
      "Accept" => "application/json",
      "Accept-Language" => "fr-FR",
    }
  end

  def map_property_type
    case @profile.property_type
    when "apartment", "studio" then "1"
    when "house" then "2"
    else "1"
    end
  end

  def parse_listing(item)
    return nil unless item["id"]

    photos = if item["photos"].is_a?(Array)
      item["photos"].map { |p| p.is_a?(Hash) ? p["url"] : p }.compact
    else
      []
    end

    {
      platform: "seloger",
      external_id: item["id"].to_s,
      title: item["title"].presence || "#{item['propertyType']} — #{item['city']}",
      description: item["description"],
      price: item["price"]&.to_i,
      surface: item["surface"]&.to_f,
      rooms: item["rooms"]&.to_i,
      city: item["city"],
      postal_code: item["zipcode"] || item["postalCode"],
      url: item["permalink"].presence || "https://www.seloger.com/annonces/#{item['id']}.htm",
      latitude: item["latitude"]&.to_f,
      longitude: item["longitude"]&.to_f,
      photos: photos,
      dpe_rating: item["energyPerformanceDiagnostic"].presence,
      published_at: item["publicationDate"] ? Time.parse(item["publicationDate"]) : Time.current
    }
  rescue StandardError => e
    Rails.logger.warn("[SeLoger] Failed to parse listing: #{e.message}")
    nil
  end
end
