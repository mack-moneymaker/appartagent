# MonitorPlatformsJob — now a no-op
#
# Previously scraped platforms. Now the app generates search URLs instead.
# Kept for backward compatibility with any scheduled jobs.
#
class MonitorPlatformsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[Monitor] Skipping — app now uses direct platform links instead of scraping")
  end
end
