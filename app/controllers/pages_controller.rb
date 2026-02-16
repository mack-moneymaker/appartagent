class PagesController < WebController
  skip_before_action :require_auth

  def home
  end

  def pricing
  end

  def how_it_works
  end
end
