class ListingsController < WebController
  skip_before_action :require_auth, only: [:index]

  def index
    @listings = Listing.order(published_at: :desc)
    @listings = @listings.where("city ILIKE ?", "%#{params[:city]}%") if params[:city].present?
    @listings = @listings.where("price <= ?", params[:max_price].to_i) if params[:max_price].present?
    @listings = @listings.where("price >= ?", params[:min_price].to_i) if params[:min_price].present?
    @listings = @listings.where(platform: params[:platform]) if params[:platform].present?

    @page = (params[:page] || 1).to_i
    @per_page = 12
    @total = @listings.count
    @listings = @listings.offset((@page - 1) * @per_page).limit(@per_page)
    @total_pages = (@total.to_f / @per_page).ceil
  end

  def show
    @listing = Listing.find(params[:id])
    @score_breakdown = ListingScorer.new(@listing).breakdown
    @neighborhood_avg = Listing.where(city: @listing.city, neighborhood: @listing.neighborhood)
                               .where.not(price_per_sqm: nil)
                               .average(:price_per_sqm)&.round(2)
  end
end
