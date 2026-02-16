class SearchProfilesController < WebController
  before_action :set_search_profile, only: [:show, :edit, :update, :destroy]

  def index
    @search_profiles = current_user.search_profiles.order(created_at: :desc)
  end

  def show
  end

  def new
    @search_profile = current_user.search_profiles.new
  end

  def create
    @search_profile = current_user.search_profiles.new(search_profile_params)
    if @search_profile.save
      redirect_to dashboard_path, notice: "Recherche créée avec succès !"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @search_profile.update(search_profile_params)
      redirect_to dashboard_path, notice: "Recherche mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @search_profile.destroy
    redirect_to dashboard_path, notice: "Recherche supprimée."
  end

  private

  def set_search_profile
    @search_profile = current_user.search_profiles.find(params[:id])
  end

  def search_profile_params
    params.require(:search_profile).permit(
      :city, :arrondissement, :min_budget, :max_budget,
      :min_surface, :max_surface, :min_rooms, :max_rooms,
      :furnished, :dpe_max, :property_type, :keywords, :active,
      platforms_to_monitor: []
    )
  end
end
