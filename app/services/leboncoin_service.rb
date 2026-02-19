# LeBonCoin Service
#
# Uses the mobile API at https://api.leboncoin.fr/finder/search
# This may break if the API key rotates or they add stricter auth.
#
class LeboncoinService
  BASE_URL = "https://api.leboncoin.fr".freeze
  SEARCH_ENDPOINT = "/finder/search".freeze
  API_KEY = "ba0c2dad52b3ec".freeze
  CATEGORY_RENTAL = "10".freeze
  USER_AGENT = "LBC;Android;15.2.0;Google Pixel 7".freeze

  # Paris arrondissement zip codes
  PARIS_ZIPCODES = (1..20).map { |n| "750#{n.to_s.rjust(2, '0')}" }.freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[LeBonCoin] Fetching listings for profile ##{@profile.id} — #{@profile.city}")

    payload = build_payload
    response = HTTParty.post(
      "#{BASE_URL}#{SEARCH_ENDPOINT}",
      body: payload.to_json,
      headers: request_headers,
      timeout: 20
    )

    unless response.success?
      Rails.logger.error("[LeBonCoin] HTTP #{response.code}: #{response.body&.first(300)}")
      return []
    end

    data = response.parsed_response
    items = data["ads"] || []

    listings = items.filter_map { |item| parse_listing(item) }
    Rails.logger.info("[LeBonCoin] Found #{listings.size} listings")
    listings
  rescue HTTParty::Error, Timeout::Error, SocketError, JSON::ParserError => e
    Rails.logger.error("[LeBonCoin] Fetch failed: #{e.class}: #{e.message}")
    []
  end

  private

  def build_payload
    location = build_location
    ranges = {
      price: { min: @profile.min_budget, max: @profile.max_budget }.compact,
      square: { min: @profile.min_surface, max: @profile.max_surface }.compact,
      rooms: { min: @profile.min_rooms, max: @profile.max_rooms }.compact
    }.reject { |_, v| v.empty? }

    enums = { ad_type: ["offer"] }
    enums[:real_estate_type] = [map_property_type] if @profile.property_type.present?
    enums[:furnished] = ["1"] if @profile.furnished

    {
      limit: 35,
      limit_alu: 3,
      filters: {
        category: { id: CATEGORY_RENTAL },
        enums: enums,
        location: location,
        ranges: ranges
      },
      sort_by: "time",
      sort_order: "desc"
    }
  end

  def build_location
    city = @profile.city&.downcase&.strip || "paris"

    if city == "paris" && @profile.arrondissement.present?
      { city_zipcodes: [{ zipcode: @profile.arrondissement }] }
    elsif city == "paris"
      { city_zipcodes: PARIS_ZIPCODES.map { |z| { zipcode: z } } }
    else
      { locations: [{ locationType: "city", label: @profile.city&.capitalize }] }
    end
  end

  def map_property_type
    case @profile.property_type
    when "apartment", "studio" then "2"  # appartement
    when "house" then "1"                 # maison
    else "2"
    end
  end

  def request_headers
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "User-Agent" => USER_AGENT,
      "api_key" => API_KEY
    }
  end

  def parse_listing(item)
    return nil unless item["list_id"]

    # Extract attributes from the attributes array
    attrs = {}
    (item["attributes"] || []).each do |attr|
      attrs[attr["key"]] = attr["value"]
    end

    price = item.dig("price")&.first || attrs["price"]&.to_i
    surface = attrs["square"]&.to_f
    rooms = attrs["rooms"]&.to_i
    furnished = attrs["furnished"] == "1"
    dpe = attrs["energy_rate"]

    photos = (item["images"]&.dig("urls") || item["images"]&.dig("urls_large") || [])

    {
      platform: "leboncoin",
      external_id: item["list_id"].to_s,
      title: item["subject"],
      description: item["body"],
      price: price&.to_i,
      surface: surface,
      rooms: rooms,
      city: item.dig("location", "city"),
      postal_code: item.dig("location", "zipcode"),
      neighborhood: item.dig("location", "neighborhood"),
      latitude: item.dig("location", "lat"),
      longitude: item.dig("location", "lng"),
      photos: photos,
      dpe_rating: dpe,
      furnished: furnished,
      published_at: item["first_publication_date"] ? Time.parse(item["first_publication_date"]) : Time.current,
      url: item["url"].presence || "https://www.leboncoin.fr/locations/#{item['list_id']}.htm"
    }
  rescue StandardError => e
    Rails.logger.warn("[LeBonCoin] Failed to parse listing: #{e.message}")
    nil
  end
end
