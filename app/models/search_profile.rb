class SearchProfile < ApplicationRecord
  belongs_to :user
  has_many :alerts, dependent: :destroy

  validates :city, presence: { message: "La ville est obligatoire" }
  validates :max_budget, presence: { message: "Le budget maximum est obligatoire" }
  validates :transaction_type, inclusion: { in: %w[rental sale], message: "Le type de transaction doit être location ou vente" }

  serialize :platforms_to_monitor, coder: JSON

  PLATFORMS = %w[seloger leboncoin pap bienici].freeze
  PROPERTY_TYPES = %w[appartement maison studio loft duplex].freeze
  PROPERTY_TYPE_LABELS = {
    "appartement" => "Appartement",
    "maison" => "Maison",
    "studio" => "Studio",
    "loft" => "Loft",
    "duplex" => "Duplex"
  }.freeze
  DPE_RATINGS = %w[A B C D E F G].freeze
  TRANSACTION_TYPES = %w[rental sale].freeze
  TRANSACTION_TYPE_LABELS = {
    "rental" => "Location",
    "sale" => "Achat"
  }.freeze

  def platforms
    platforms_to_monitor || PLATFORMS
  end

  def transaction_label
    TRANSACTION_TYPE_LABELS[transaction_type] || "Location"
  end

  def property_type_label
    PROPERTY_TYPE_LABELS[property_type] || property_type&.capitalize
  end

  def budget_label
    unit = transaction_type == "sale" ? "€" : "€/mois"
    if min_budget.present? && max_budget.present?
      "#{min_budget}–#{max_budget} #{unit}"
    elsif max_budget.present?
      "≤ #{max_budget} #{unit}"
    elsif min_budget.present?
      "≥ #{min_budget} #{unit}"
    else
      "—"
    end
  end

  def rooms_label
    if min_rooms.present? && max_rooms.present?
      min_rooms == max_rooms ? "#{min_rooms} pièce#{'s' if min_rooms > 1}" : "#{min_rooms}–#{max_rooms} pièces"
    elsif min_rooms.present?
      "≥ #{min_rooms} pièces"
    elsif max_rooms.present?
      "≤ #{max_rooms} pièces"
    end
  end

  def surface_label
    if min_surface.present? && max_surface.present?
      "#{min_surface}–#{max_surface} m²"
    elsif min_surface.present?
      "≥ #{min_surface} m²"
    elsif max_surface.present?
      "≤ #{max_surface} m²"
    end
  end

  def summary
    parts = []
    parts << "#{city}#{" #{arrondissement}" if arrondissement.present?}"
    parts << rooms_label if rooms_label
    parts << budget_label
    parts.join(", ")
  end

  def matches_listing?(listing)
    return false if city.present? && listing.city&.downcase != city.downcase
    return false if min_budget.present? && listing.price < min_budget
    return false if max_budget.present? && listing.price > max_budget
    return false if min_surface.present? && listing.surface && listing.surface < min_surface
    return false if max_surface.present? && listing.surface && listing.surface > max_surface
    return false if min_rooms.present? && listing.rooms && listing.rooms < min_rooms
    return false if max_rooms.present? && listing.rooms && listing.rooms > max_rooms
    return false if furnished == true && listing.furnished != true
    return false if property_type.present? && listing.description&.downcase&.exclude?(property_type)
    true
  end
end
