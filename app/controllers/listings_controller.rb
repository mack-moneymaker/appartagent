class ListingsController < WebController
  def show
    @listing = Listing.find(params[:id])
    @score_breakdown = ListingScorer.new(@listing).breakdown
    @neighborhood_avg = Listing.where(city: @listing.city, neighborhood: @listing.neighborhood)
                               .where.not(price_per_sqm: nil)
                               .average(:price_per_sqm)&.round(2)
  end
end
