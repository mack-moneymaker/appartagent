# Bien'ici Service — French real estate aggregator
#
# Uses their public search API (POST JSON).
# Zone IDs are resolved via autocomplete, with fallback hardcoded values.
#
class BienciService
  BASE_URL = "https://www.bienici.com".freeze
  SEARCH_URL = "#{BASE_URL}/realEstateAds.json".freeze
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36".freeze

  # Hardcoded zone IDs for major cities (fallback)
  ZONE_IDS = {
    "paris" => "-7444",
    "lyon" => "-69123",
    "marseille" => "-13055",
    "bordeaux" => "-33063",
    "toulouse" => "-31555",
    "nantes" => "-44109",
    "lille" => "-59350",
    "montpellier" => "-34172",
    "nice" => "-6088",
    "strasbourg" => "-67482",
    "rennes" => "-35238"
  }.freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[Bien'ici] Fetching listings for profile ##{@profile.id} — #{@profile.city}")

    zone_id = resolve_zone_id
    unless zone_id
      Rails.logger.warn("[Bien'ici] Could not resolve zone ID for #{@profile.city}")
      return []
    end

    payload = build_payload(zone_id)
    response = HTTParty.post(
      SEARCH_URL,
      body: payload.to_json,
      headers: request_headers,
      timeout: 20
    )

    unless response.success?
      Rails.logger.error("[Bien'ici] HTTP #{response.code}: #{response.body&.first(200)}")
      return []
    end

    data = response.parsed_response
    items = data["realEstateAds"] || []

    listings = items.filter_map { |item| parse_listing(item) }
    Rails.logger.info("[Bien'ici] Found #{listings.size} listings")
    listings
  rescue HTTParty::Error, Timeout::Error, SocketError, JSON::ParserError => e
    Rails.logger.error("[Bien'ici] Fetch failed: #{e.class}: #{e.message}")
    []
  end

  private

  def resolve_zone_id
    city_key = @profile.city&.downcase&.strip&.gsub(/\s+/, "-") || "paris"
    cached = ZONE_IDS[city_key.split("-").first]
    return cached if cached

    # Try autocomplete API
    resp = HTTParty.get(
      "#{BASE_URL}/realEstateAds/zoneIdsByTypes",
      query: { text: @profile.city },
      headers: { "User-Agent" => USER_AGENT },
      timeout: 10
    )
    if resp.success? && resp.parsed_response.is_a?(Hash)
      ids = resp.parsed_response["zoneIds"]
      return ids.first if ids&.any?
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("[Bien'ici] Zone ID resolution failed: #{e.message}")
    nil
  end

  def build_payload(zone_id)
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
      zoneIdsByTypes: { zoneIds: [zone_id] },
      size: 24,
      from: 0,
      sortBy: "publicationDate",
      sortOrder: "desc"
    }
  end

  def request_headers
    {
      "Content-Type" => "application/json",
      "User-Agent" => USER_AGENT,
      "Accept" => "application/json",
      "Accept-Language" => "fr-FR,fr;q=0.9",
      "Origin" => BASE_URL,
      "Referer" => "#{BASE_URL}/recherche/"
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
    return nil unless item["id"]

    photos = if item["photos"].is_a?(Array)
      item["photos"].map { |p| p.is_a?(Hash) ? (p["url"] || p["url_photo"]) : p }.compact
    else
      []
    end

    {
      platform: "bienici",
      external_id: item["id"].to_s,
      title: item["title"].presence || "#{item['propertyType']} #{item['roomsQuantity']}p #{item['area']}m²",
      description: item["description"],
      price: item["price"]&.to_i,
      surface: item["area"]&.to_f,
      rooms: item["roomsQuantity"]&.to_i,
      city: item["city"],
      postal_code: item["postalCode"],
      neighborhood: item["district"].presence,
      address: item["address"].presence,
      latitude: item.dig("blurInfo", "position", "lat") || item["latitude"],
      longitude: item.dig("blurInfo", "position", "lng") || item["longitude"],
      photos: photos,
      dpe_rating: item["energyClassification"].presence,
      furnished: item["isFurnished"],
      published_at: item["publicationDate"] ? Time.parse(item["publicationDate"]) : Time.current,
      url: "#{BASE_URL}/annonce/location/#{item['id']}"
    }
  rescue StandardError => e
    Rails.logger.warn("[Bien'ici] Failed to parse listing: #{e.message}")
    nil
  end
end
