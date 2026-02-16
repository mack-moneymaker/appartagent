class ApplicationTemplate < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :content, presence: true

  # Available variables: {nom}, {adresse}, {prix}, {surface}, {quartier}, {date}
  def render_for(listing, user)
    content
      .gsub("{nom}", user.name.to_s)
      .gsub("{adresse}", listing.address.to_s)
      .gsub("{prix}", listing.price.to_s)
      .gsub("{surface}", listing.surface.to_s)
      .gsub("{quartier}", listing.neighborhood.to_s)
      .gsub("{date}", Date.current.strftime("%d/%m/%Y"))
  end
end
