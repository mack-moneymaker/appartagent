class WebController < ApplicationController
  before_action :require_auth

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_auth
    unless logged_in?
      redirect_to login_path, alert: "Veuillez vous connecter."
    end
  end
end
