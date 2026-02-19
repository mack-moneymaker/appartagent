module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_key!

    private

    def authenticate_api_key!
      token = request.headers["Authorization"]&.sub(/^Bearer\s+/, "")
      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, ENV.fetch("SCRAPER_API_KEY", ""))
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
