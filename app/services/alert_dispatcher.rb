# AlertDispatcher — sends alerts via email, SMS, or push
#
class AlertDispatcher
  def initialize(alert)
    @alert = alert
  end

  def dispatch!
    case @alert.channel
    when "email"
      send_email
    when "sms"
      send_sms
    when "push"
      send_push
    end
    @alert.update!(sent_at: Time.current)
  end

  private

  def send_email
    AlertMailer.new_listing_alert(@alert).deliver_later
  end

  def send_sms
    # STUB: SMS integration
    # Options being evaluated (see GitHub issue #3):
    # - Twilio: most mature, but US-based pricing
    # - OVH SMS: French provider, competitive pricing for FR numbers
    # - Vonage (Nexmo): good EU coverage
    # - sms-envoi.com: French specialist
    #
    # Implementation would be:
    # SmsProvider.send(
    #   to: @alert.user.phone,
    #   body: "🏠 Nouveau logement: #{@alert.listing.title} — #{@alert.listing.price}€ — #{@alert.listing.url}"
    # )
    Rails.logger.info("[SMS] Would send alert ##{@alert.id} to #{@alert.user.phone}")
  end

  def send_push
    # STUB: Push notification (future feature)
    Rails.logger.info("[Push] Would send push for alert ##{@alert.id}")
  end
end
