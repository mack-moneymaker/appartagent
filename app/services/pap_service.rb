# PAP URL Generator (De Particulier à Particulier)
#
# Generates pre-filled search URLs for PAP.fr based on search criteria.
#
class PapService
  PLATFORM_NAME = "PAP".freeze
  PLATFORM_KEY = "pap".freeze
  DESCRIPTION = "Annonces exclusivement entre particuliers. Pas de frais d'agence.".freeze
  COLOR = "text-blue-600".freeze
  BG_COLOR = "bg-blue-50".freeze
  BORDER_COLOR = "border-blue-200".freeze

  def initialize(search_profile)
    @profile = search_profile
  end

  def search_url
    type = @profile.transaction_type == "sale" ? "vente" : "location"
    property = "appartement"
    city = (@profile.city&.strip || "Paris").downcase.gsub(/\s+/, "-")

    # PAP uses path-based filtering
    path_parts = ["#{type}-#{property}-#{city}"]

    path_parts << "prix-max-#{@profile.max_budget}" if @profile.max_budget
    path_parts << "prix-min-#{@profile.min_budget}" if @profile.min_budget
    path_parts << "surface-min-#{@profile.min_surface}" if @profile.min_surface
    path_parts << "nb-pieces-min-#{@profile.min_rooms}" if @profile.min_rooms

    "https://www.pap.fr/annonce/#{path_parts.join('-')}"
  end

  def self.platform_info
    { name: PLATFORM_NAME, key: PLATFORM_KEY, description: DESCRIPTION,
      color: COLOR, bg_color: BG_COLOR, border_color: BORDER_COLOR, emoji: "🔵" }
  end
end
