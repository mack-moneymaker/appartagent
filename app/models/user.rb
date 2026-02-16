class User < ApplicationRecord
  has_secure_password

  has_many :search_profiles, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :auto_replies, dependent: :destroy
  has_many :application_templates, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :plan, inclusion: { in: %w[free pro premium] }

  def pro_or_premium?
    plan.in?(%w[pro premium])
  end

  def premium?
    plan == "premium"
  end

  def max_search_profiles
    case plan
    when "free" then 1
    when "pro" then 5
    when "premium" then Float::INFINITY
    end
  end
end
