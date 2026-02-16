class SearchProfile < ApplicationRecord
  belongs_to :user
  has_many :alerts, dependent: :destroy

  validates :city, presence: true
  validates :max_budget, presence: true

  serialize :platforms_to_monitor, coder: JSON

  PLATFORMS = %w[seloger leboncoin pap bienici].freeze
  PROPERTY_TYPES = %w[apartment studio house].freeze
  DPE_RATINGS = %w[A B C D E F G].freeze

  def platforms
    platforms_to_monitor || PLATFORMS
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
