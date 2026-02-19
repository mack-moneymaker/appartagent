# SeLoger URL Generator
#
# Generates pre-filled search URLs for SeLoger.com based on search criteria.
#
class SelogerService
  PLATFORM_NAME = "SeLoger".freeze
  PLATFORM_KEY = "seloger".freeze
  DESCRIPTION = "Leader de l'immobilier en ligne. Annonces de professionnels principalement.".freeze
  COLOR = "text-red-500".freeze
  BG_COLOR = "bg-red-50".freeze
  BORDER_COLOR = "border-red-200".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def search_url
    project = @profile.transaction_type == "sale" ? "2" : "1"
    city = (@profile.city&.strip || "Paris").downcase.gsub(/\s+/, "-")
    type_path = @profile.transaction_type == "sale" ? "achat" : "location"

    # SeLoger uses path-based search URLs
    base = "https://www.seloger.com/list.htm"
    params = {
      projects: project,
      types: "1,2", # appartement + maison
      places: "[{cp:#{@profile.postal_code || ''}}]",
      price: price_range,
      surface: surface_range,
      rooms: rooms_range
    }.compact

    base + "?" + URI.encode_www_form(params)
  end

  def self.platform_info
    { name: PLATFORM_NAME, key: PLATFORM_KEY, description: DESCRIPTION,
      color: COLOR, bg_color: BG_COLOR, border_color: BORDER_COLOR, emoji: "🔴" }
  end

  private

  def price_range
    min = @profile.min_budget
    max = @profile.max_budget
    return nil unless min || max
    "#{min || 'NaN'}/#{max || 'NaN'}"
  end

  def surface_range
    min = @profile.min_surface
    return nil unless min
    "#{min}/NaN"
  end

  def rooms_range
    min = @profile.min_rooms
    return nil unless min
    "#{min}/NaN"
  end
end
