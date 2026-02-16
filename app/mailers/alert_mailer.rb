class AlertMailer < ApplicationMailer
  def new_listing_alert(alert)
    @alert = alert
    @listing = alert.listing
    @user = alert.user
    @profile = alert.search_profile

    mail(
      to: @user.email,
      subject: "🏠 Nouveau logement : #{@listing.title} — #{@listing.price}€/mois"
    )
  end
end
