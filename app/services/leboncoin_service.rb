# LeBonCoin URL Generator
#
# Generates pre-filled search URLs for LeBonCoin based on search criteria.
#
class LeboncoinService
  PLATFORM_NAME = "LeBonCoin".freeze
  PLATFORM_KEY = "leboncoin".freeze
  DESCRIPTION = "Le plus grand site de petites annonces en France. Annonces de particuliers et professionnels.".freeze
  COLOR = "text-orange-500".freeze
  BG_COLOR = "bg-orange-50".freeze
  BORDER_COLOR = "border-orange-200".freeze

  CATEGORY_RENTAL = "10".freeze
  CATEGORY_SALE = "9".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def search_url
    category = @profile.transaction_type == "sale" ? CATEGORY_SALE : CATEGORY_RENTAL
    city = @profile.city&.strip || "Paris"

    params = { category: category, text: city }
    params[:locations] = city
    params[:price] = price_range if price_range
    params[:square] = surface_range if surface_range
    params[:rooms] = rooms_range if rooms_range
    params[:furnished] = "1" if @profile.furnished? && @profile.transaction_type == "rental"

    "https://www.leboncoin.fr/recherche?" + URI.encode_www_form(params)
  end

  def self.platform_info
    { name: PLATFORM_NAME, key: PLATFORM_KEY, description: DESCRIPTION,
      color: COLOR, bg_color: BG_COLOR, border_color: BORDER_COLOR, emoji: "🟠" }
  end

  private

  def price_range
    min = @profile.min_budget
    max = @profile.max_budget
    return nil unless min || max
    "#{min || ''}-#{max || ''}"
  end

  def surface_range
    min = @profile.min_surface
    return nil unless min
    "#{min}-"
  end

  def rooms_range
    min = @profile.min_rooms
    return nil unless min
    "#{min}-"
  end
end
