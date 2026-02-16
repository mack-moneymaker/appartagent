class SendAutoReplyJob < ApplicationJob
  queue_as :default

  def perform(auto_reply_id)
    auto_reply = AutoReply.find(auto_reply_id)
    AutoReplyService.new(auto_reply).send!
  end
end
