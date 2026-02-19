module Api
  class SearchProfilesController < BaseController
    # GET /api/search_profiles
    def index
      profiles = SearchProfile.where(active: true).includes(:user)
      render json: profiles.map { |p|
        {
          id: p.id,
          city: p.city,
          arrondissement: p.arrondissement,
          min_budget: p.min_budget,
          max_budget: p.max_budget,
          min_surface: p.min_surface,
          max_surface: p.max_surface,
          min_rooms: p.min_rooms,
          max_rooms: p.max_rooms,
          property_type: p.property_type,
          furnished: p.furnished,
          platforms: p.platforms,
          transaction_type: p.try(:transaction_type) || "rental"
        }
      }
    end
  end
end
