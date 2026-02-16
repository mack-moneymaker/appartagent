class AutoRepliesController < WebController
  def index
    @auto_replies = current_user.auto_replies.includes(:listing).recent
    @templates = current_user.application_templates
  end

  def create
    listing = Listing.find(params[:listing_id])
    template = current_user.application_templates.find(params[:template_id])
    message = template.render_for(listing, current_user)

    @auto_reply = current_user.auto_replies.new(
      listing: listing,
      message_text: message,
      platform: listing.platform,
      status: "pending"
    )

    if @auto_reply.save
      SendAutoReplyJob.perform_later(@auto_reply.id)
      redirect_to auto_replies_path, notice: "Réponse automatique envoyée !"
    else
      redirect_to listing_path(listing), alert: "Erreur lors de l'envoi."
    end
  end
end
