class ApplicationTemplatesController < WebController
  before_action :set_template, only: [:edit, :update, :destroy]

  def index
    @templates = current_user.application_templates
  end

  def new
    @template = current_user.application_templates.new
  end

  def create
    @template = current_user.application_templates.new(template_params)
    if @template.save
      redirect_to application_templates_path, notice: "Modèle créé avec succès !"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to application_templates_path, notice: "Modèle mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy
    redirect_to application_templates_path, notice: "Modèle supprimé."
  end

  private

  def set_template
    @template = current_user.application_templates.find(params[:id])
  end

  def template_params
    params.require(:application_template).permit(:name, :content)
  end
end
