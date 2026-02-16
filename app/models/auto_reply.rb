class AutoReply < ApplicationRecord
  belongs_to :user
  belongs_to :listing

  validates :message_text, presence: true
  validates :platform, presence: true
  validates :status, inclusion: { in: %w[pending sent failed] }

  scope :recent, -> { order(created_at: :desc) }
end
