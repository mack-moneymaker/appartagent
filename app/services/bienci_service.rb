# Bien'ici URL Generator
#
# Generates pre-filled search URLs for Bienici.com based on search criteria.
#
class BienciService
  PLATFORM_NAME = "Bien'ici".freeze
  PLATFORM_KEY = "bienici".freeze
  DESCRIPTION = "Agrégateur d'annonces immobilières avec carte interactive détaillée.".freeze
  COLOR = "text-teal-500".freeze
  BG_COLOR = "bg-teal-50".freeze
  BORDER_COLOR = "border-teal-200".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def search_url
    type = @profile.transaction_type == "sale" ? "achat" : "location"
    city = (@profile.city&.strip || "Paris").downcase.gsub(/\s+/, "-")

    base = "https://www.bienici.com/recherche/#{type}/#{city}"
    params = {}
    params["prix-min"] = @profile.min_budget if @profile.min_budget
    params["prix-max"] = @profile.max_budget if @profile.max_budget
    params["surface-min"] = @profile.min_surface if @profile.min_surface
    params["pieces-min"] = @profile.min_rooms if @profile.min_rooms

    return base if params.empty?
    base + "?" + URI.encode_www_form(params)
  end

  def self.platform_info
    { name: PLATFORM_NAME, key: PLATFORM_KEY, description: DESCRIPTION,
      color: COLOR, bg_color: BG_COLOR, border_color: BORDER_COLOR, emoji: "🟢" }
  end
end
