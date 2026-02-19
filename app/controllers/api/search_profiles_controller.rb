module Api
  class SearchProfilesController < BaseController
    # GET /api/search_profiles
    def index
      profiles = SearchProfile.where(active: true).includes(:user)
      render json: serialize_profiles(profiles)
    end

    # GET /api/search_profiles/pending
    def pending
      profiles = SearchProfile.where(active: true, needs_scrape: true).includes(:user)
      render json: serialize_profiles(profiles)
    end

    # PATCH /api/search_profiles/:id/scraped
    def scraped
      profile = SearchProfile.find(params[:id])
      profile.update_columns(needs_scrape: false, scraped_at: Time.current)
      render json: { ok: true }
    end

    # PATCH /api/search_profiles/:id/request_scrape
    def request_scrape
      profile = SearchProfile.find(params[:id])
      profile.update_columns(needs_scrape: true)
      render json: { ok: true }
    end

    private

    def serialize_profiles(profiles)
      profiles.map { |p|
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
          transaction_type: p.try(:transaction_type) || "rental",
          needs_scrape: p.try(:needs_scrape) || false,
          scraped_at: p.try(:scraped_at)
        }
      }
    end
  end
end
