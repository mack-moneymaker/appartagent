class DashboardController < WebController
  def index
    @search_profiles = current_user.search_profiles.order(created_at: :desc)
    @recent_alerts = current_user.alerts.includes(:listing, :search_profile).recent.limit(10)
    @stats = {
      listings_scanned: Listing.count,
      matches_found: current_user.alerts.count,
      unseen_alerts: current_user.alerts.unseen.count,
      auto_replies_sent: current_user.auto_replies.where(status: "sent").count
    }
  end
end
