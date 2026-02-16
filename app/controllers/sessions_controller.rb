class SessionsController < WebController
  skip_before_action :require_auth, only: [:new, :create]

  def new
  end

  def create
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Bienvenue, #{user.name} !"
    else
      flash.now[:alert] = "Email ou mot de passe incorrect."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "Déconnecté avec succès."
  end
end
