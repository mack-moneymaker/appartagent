class SavedListingsController < WebController
  before_action :set_saved_listing, only: [:update, :destroy]

  def index
    @saved_listings = current_user.saved_listings.recent
    @saved_listings = @saved_listings.by_status(params[:status]) if params[:status].present?

    # Sorting
    sort_col = %w[price surface rooms price_per_sqm created_at status].include?(params[:sort]) ? params[:sort] : "created_at"
    sort_dir = params[:dir] == "asc" ? :asc : :desc
    @saved_listings = @saved_listings.reorder(sort_col => sort_dir)
  end

  def create
    @saved_listing = current_user.saved_listings.new(saved_listing_params)
    @saved_listing.search_profile_id = params[:saved_listing][:search_profile_id] if params[:saved_listing][:search_profile_id].present?

    if @saved_listing.save
      redirect_back fallback_location: saved_listings_path, notice: "Annonce sauvegardée !"
    else
      redirect_back fallback_location: saved_listings_path, alert: @saved_listing.errors.full_messages.join(", ")
    end
  end

  def update
    if @saved_listing.update(saved_listing_update_params)
      redirect_back fallback_location: saved_listings_path, notice: "Annonce mise à jour."
    else
      redirect_back fallback_location: saved_listings_path, alert: @saved_listing.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saved_listing.destroy
    redirect_to saved_listings_path, notice: "Annonce supprimée."
  end

  private

  def set_saved_listing
    @saved_listing = current_user.saved_listings.find(params[:id])
  end

  def saved_listing_params
    params.require(:saved_listing).permit(:url, :title, :price, :surface, :rooms, :city, :notes, :rating, :status, :search_profile_id)
  end

  def saved_listing_update_params
    params.require(:saved_listing).permit(:title, :price, :surface, :rooms, :city, :notes, :rating, :status)
  end
end
