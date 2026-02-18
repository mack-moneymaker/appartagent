# PAP Service (De Particulier à Particulier)
#
# Scrapes PAP.fr for rental listings using Nokogiri + HTTParty.
# PAP is the least protected major French rental platform.
#
class PapService
  BASE_URL = "https://www.pap.fr".freeze
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

  # Known geo IDs for major cities
  GEO_IDS = {
    "paris" => "g439", "lyon" => "g30893", "marseille" => "g30988",
    "bordeaux" => "g30392", "toulouse" => "g31555", "nantes" => "g31232",
    "lille" => "g30821", "montpellier" => "g31080", "nice" => "g31252",
    "strasbourg" => "g31506", "rennes" => "g31355"
  }.freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def fetch_listings
    Rails.logger.info("[PAP] Fetching listings for profile ##{@profile.id} — #{@profile.city}")

    listings = []
    [1, 2].each do |page|
      url = search_url(page)
      Rails.logger.info("[PAP] Fetching page #{page}: #{url}")

      response = HTTParty.get(url, headers: request_headers, timeout: 15)
      break unless response.success?

      doc = Nokogiri::HTML(response.body)
      page_listings = extract_listings(doc)
      break if page_listings.empty?

      listings.concat(page_listings)
      sleep(2) if page < 2 # Be respectful
    end

    Rails.logger.info("[PAP] Found #{listings.size} listings")
    listings
  rescue HTTParty::Error, Timeout::Error, SocketError => e
    Rails.logger.error("[PAP] Fetch failed: #{e.message}")
    []
  end

  private

  def search_url(page = 1)
    type = @profile.property_type == "house" ? "maison" : "appartement"
    city_key = @profile.city&.downcase&.strip&.gsub(/\s+/, "-") || "paris"
    geo = GEO_IDS[city_key.split("-").first] || "g439"

    url = "#{BASE_URL}/annonce/location-#{type}-#{city_key}-#{geo}"

    params = []
    params << "prix-max-#{@profile.max_budget}" if @profile.max_budget
    params << "prix-min-#{@profile.min_budget}" if @profile.min_budget
    params << "surface-min-#{@profile.min_surface}" if @profile.min_surface
    params << "nb-pieces-min-#{@profile.min_rooms}" if @profile.min_rooms

    url += "-#{params.join('-')}" if params.any?
    url += "?page=#{page}" if page > 1
    url
  end

  def request_headers
    {
      "User-Agent" => USER_AGENT,
      "Accept" => "text/html,application/xhtml+xml",
      "Accept-Language" => "fr-FR,fr;q=0.9",
      "Referer" => BASE_URL
    }
  end

  def extract_listings(doc)
    listings = []

    # PAP uses different selectors over time; try multiple patterns
    selectors = [
      "div.search-list-item", "a.search-list-item",
      "div[data-qa='search-result-item']", "article.item"
    ]

    items = nil
    selectors.each do |sel|
      items = doc.css(sel)
      break if items.any?
    end

    return [] unless items&.any?

    items.each do |item|
      listing = parse_item(item)
      listings << listing if listing && listing[:title].present?
    end

    listings
  end

  def parse_item(item)
    title_el = item.css("a.item-title, h2 a, .item-description a, a[href*='/annonces/']").first
    return nil unless title_el

    href = title_el["href"]
    external_id = href&.scan(/(\d+)/)&.flatten&.first

    price_text = item.css(".item-price, .price, span[class*='price']").text
    price = price_text.gsub(/[^\d]/, "").to_i
    price = nil if price == 0

    tags_text = item.css(".item-tags li, .item-tags span, .tags span").map(&:text)
    surface = nil
    rooms = nil

    tags_text.each do |tag|
      if tag =~ /(\d+)\s*m²/
        surface = $1.to_f
      elsif tag =~ /(\d+)\s*p(?:ièce|ce)/i
        rooms = $1.to_i
      end
    end

    # Try extracting from description if tags didn't work
    desc = item.css(".item-description, .description").text.strip
    surface ||= desc.scan(/(\d+)\s*m²/).flatten.first&.to_f
    rooms ||= desc.scan(/(\d+)\s*pièce/i).flatten.first&.to_i

    photo = item.css("img[src*='photo'], img[data-src]").first
    photo_url = photo&.[]("src") || photo&.[]("data-src")

    {
      platform: "pap",
      external_id: external_id || SecureRandom.hex(8),
      title: title_el.text.strip,
      description: desc.presence,
      price: price,
      surface: surface,
      rooms: rooms,
      city: @profile.city,
      postal_code: @profile.arrondissement,
      photos: [photo_url].compact,
      url: href&.start_with?("http") ? href : "#{BASE_URL}#{href}",
      published_at: Time.current
    }
  end
end
