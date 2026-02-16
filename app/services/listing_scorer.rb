# ListingScorer — scores listings on a 0-100 scale
#
# Scoring factors (weighted):
# - Price per m² vs city average (30%)
# - DPE rating (20%)
# - Freshness of listing (25%)
# - Surface for price ratio (15%)
# - Completeness of listing info (10%)
#
class ListingScorer
  WEIGHTS = {
    price_value: 0.30,
    dpe: 0.20,
    freshness: 0.25,
    space_value: 0.15,
    completeness: 0.10
  }.freeze

  DPE_SCORES = {
    "A" => 100, "B" => 85, "C" => 70, "D" => 55,
    "E" => 40, "F" => 25, "G" => 10
  }.freeze

  # Average price per m² by major French cities (€/m² monthly rent, approximate 2024)
  CITY_AVERAGES = {
    "paris" => 35.0,
    "lyon" => 18.0,
    "marseille" => 15.0,
    "bordeaux" => 17.0,
    "toulouse" => 14.0,
    "nantes" => 15.0,
    "lille" => 16.0,
    "montpellier" => 16.0,
    "nice" => 20.0,
    "strasbourg" => 14.0
  }.freeze

  DEFAULT_AVERAGE = 16.0

  def initialize(listing)
    @listing = listing
  end

  def score
    total = 0.0
    WEIGHTS.each do |factor, weight|
      total += send(:"score_#{factor}") * weight
    end
    total.round(1)
  end

  def breakdown
    WEIGHTS.map do |factor, weight|
      raw = send(:"score_#{factor}")
      {
        factor: factor,
        label: factor_label(factor),
        raw_score: raw.round(1),
        weighted: (raw * weight).round(1),
        weight: (weight * 100).to_i
      }
    end
  end

  private

  def score_price_value
    return 50.0 unless @listing.price_per_sqm && @listing.city
    avg = CITY_AVERAGES[@listing.city.downcase] || DEFAULT_AVERAGE
    ratio = @listing.price_per_sqm / avg
    # Below average = good (higher score), above = bad
    case ratio
    when 0..0.7 then 100.0
    when 0.7..0.85 then 90.0
    when 0.85..1.0 then 75.0
    when 1.0..1.15 then 60.0
    when 1.15..1.3 then 40.0
    else 20.0
    end
  end

  def score_dpe
    DPE_SCORES[@listing.dpe_rating&.upcase] || 50.0
  end

  def score_freshness
    return 50.0 unless @listing.published_at
    hours_old = (Time.current - @listing.published_at) / 1.hour
    case hours_old
    when 0..1 then 100.0
    when 1..6 then 90.0
    when 6..24 then 75.0
    when 24..72 then 50.0
    when 72..168 then 30.0
    else 10.0
    end
  end

  def score_space_value
    return 50.0 unless @listing.surface && @listing.price
    sqm_per_100eur = (@listing.surface / (@listing.price / 100.0))
    case sqm_per_100eur
    when 3.. then 100.0
    when 2..3 then 80.0
    when 1.5..2 then 60.0
    when 1..1.5 then 40.0
    else 20.0
    end
  end

  def score_completeness
    fields = [:description, :surface, :rooms, :dpe_rating, :photos, :address, :neighborhood]
    filled = fields.count { |f| @listing.send(f).present? }
    (filled.to_f / fields.size * 100).round(1)
  end

  def factor_label(factor)
    {
      price_value: "Prix / m² vs moyenne",
      dpe: "Diagnostic énergétique (DPE)",
      freshness: "Fraîcheur de l'annonce",
      space_value: "Rapport surface / prix",
      completeness: "Complétude de l'annonce"
    }[factor]
  end
end
