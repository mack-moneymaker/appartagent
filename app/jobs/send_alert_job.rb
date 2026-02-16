class SendAlertJob < ApplicationJob
  queue_as :default

  def perform(alert_id)
    alert = Alert.find(alert_id)
    AlertDispatcher.new(alert).dispatch!
  end
end
