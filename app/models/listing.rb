class Listing < ApplicationRecord
  has_many :alerts, dependent: :destroy
  has_many :auto_replies, dependent: :destroy

  validates :platform, presence: true, inclusion: { in: %w[seloger leboncoin pap bienici] }
  validates :external_id, presence: true, uniqueness: { scope: :platform }
  validates :title, presence: true
  validates :price, presence: true

  serialize :photos, coder: JSON

  scope :recent, -> { order(published_at: :desc) }
  scope :by_platform, ->(platform) { where(platform: platform) }

  before_save :compute_price_per_sqm

  def photo_urls
    photos || []
  end

  def first_photo
    photo_urls.first
  end

  private

  def compute_price_per_sqm
    if price.present? && surface.present? && surface > 0
      self.price_per_sqm = (price.to_f / surface).round(2)
    end
  end
end
