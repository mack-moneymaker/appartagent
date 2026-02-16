# AutoReplyService — sends personalized replies to listings on platforms
#
# Each platform has different messaging mechanisms:
# - LeBonCoin: Internal messaging system (requires auth session)
# - SeLoger: Contact form submission or email relay
# - PAP: Direct email to owner (visible in listing)
# - Bien'ici: Contact form via API
#
# See GitHub issue #2 for platform messaging research
#
class AutoReplyService
  def initialize(auto_reply)
    @auto_reply = auto_reply
    @listing = auto_reply.listing
    @user = auto_reply.user
  end

  def send!
    case @listing.platform
    when "leboncoin"
      send_via_leboncoin
    when "seloger"
      send_via_seloger
    when "pap"
      send_via_pap
    when "bienici"
      send_via_bienici
    end
  rescue StandardError => e
    @auto_reply.update!(status: "failed")
    Rails.logger.error("[AutoReply] Failed for ##{@auto_reply.id}: #{e.message}")
    raise
  end

  private

  def send_via_leboncoin
    # STUB: Would authenticate and send message via LBC internal messaging
    # POST https://api.leboncoin.fr/api/v1/threads
    # { ad_id: external_id, body: message_text }
    Rails.logger.info("[AutoReply] LeBonCoin message for listing #{@listing.external_id}")
    mark_sent!
  end

  def send_via_seloger
    # STUB: Would submit contact form
    Rails.logger.info("[AutoReply] SeLoger contact for listing #{@listing.external_id}")
    mark_sent!
  end

  def send_via_pap
    # STUB: Would send email to owner
    Rails.logger.info("[AutoReply] PAP contact for listing #{@listing.external_id}")
    mark_sent!
  end

  def send_via_bienici
    # STUB: Would submit via Bien'ici contact API
    Rails.logger.info("[AutoReply] Bien'ici contact for listing #{@listing.external_id}")
    mark_sent!
  end

  def mark_sent!
    @auto_reply.update!(status: "sent", sent_at: Time.current)
  end
end
