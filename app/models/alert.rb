class Alert < ApplicationRecord
  belongs_to :user
  belongs_to :search_profile
  belongs_to :listing

  validates :channel, inclusion: { in: %w[email sms push] }

  scope :unseen, -> { where(seen_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def seen?
    seen_at.present?
  end

  def mark_seen!
    update!(seen_at: Time.current)
  end
end
