class RegistrationsController < WebController
  skip_before_action :require_auth

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.email = @user.email&.downcase
    if @user.save
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: "Compte créé avec succès ! Bienvenue sur AppartAgent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :name, :phone, :password, :password_confirmation)
  end
end
