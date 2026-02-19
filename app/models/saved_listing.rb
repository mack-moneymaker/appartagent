class SavedListing < ApplicationRecord
  belongs_to :user
  belongs_to :search_profile, optional: true

  validates :url, presence: true, uniqueness: { scope: :user_id, message: "Cette annonce est déjà sauvegardée" }
  validates :status, inclusion: { in: %w[à\ voir visité refusé favori] }
  validates :rating, inclusion: { in: [nil, 1, 2, 3, 4, 5] }, allow_nil: true

  STATUSES = ["à voir", "visité", "refusé", "favori"].freeze
  STATUS_COLORS = {
    "à voir" => "bg-blue-100 text-blue-700",
    "visité" => "bg-yellow-100 text-yellow-700",
    "refusé" => "bg-red-100 text-red-700",
    "favori" => "bg-green-100 text-green-700"
  }.freeze

  before_save :detect_platform, :compute_price_per_sqm

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  def status_color
    STATUS_COLORS[status] || "bg-gray-100 text-gray-700"
  end

  def stars
    "★" * (rating || 0) + "☆" * (5 - (rating || 0))
  end

  private

  def detect_platform
    return if platform.present? || url.blank?
    self.platform = case url
    when /leboncoin/ then "leboncoin"
    when /seloger/ then "seloger"
    when /pap\.fr/ then "pap"
    when /bienici/ then "bienici"
    when /logic-immo/ then "logic-immo"
    when /explorimmo/ then "explorimmo"
    else URI.parse(url).host&.gsub(/^www\./, "")&.split(".")&.first rescue "autre"
    end
  end

  def compute_price_per_sqm
    if price.present? && surface.present? && surface > 0
      self.price_per_sqm = (price.to_f / surface).round(2)
    end
  end
end
