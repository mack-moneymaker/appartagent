class DashboardController < WebController
  def index
    @search_profiles = current_user.search_profiles.order(created_at: :desc)
    @saved_listings = current_user.saved_listings.recent.limit(10)
    @stats = {
      search_profiles: current_user.search_profiles.count,
      saved_listings: current_user.saved_listings.count,
      favorites: current_user.saved_listings.by_status("favori").count,
      to_visit: current_user.saved_listings.by_status("à voir").count
    }
  end
end
