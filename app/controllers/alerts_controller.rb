class AlertsController < WebController
  def index
    @alerts = current_user.alerts.includes(:listing, :search_profile).recent.limit(50)
  end

  def mark_seen
    alert = current_user.alerts.find(params[:id])
    alert.mark_seen!
    redirect_to alerts_path, notice: "Alerte marquée comme vue."
  end
end
