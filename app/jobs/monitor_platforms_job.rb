class MonitorPlatformsJob < ApplicationJob
  queue_as :default

  PLATFORM_SERVICES = {
    "leboncoin" => LeboncoinService,
    "seloger" => SelogerService,
    "pap" => PapService,
    "bienici" => BienciService
  }.freeze

  def perform
    SearchProfile.where(active: true).includes(:user).find_each do |profile|
      # Free users: skip if checked in last 24h
      next if profile.user.plan == "free" && profile.updated_at > 24.hours.ago

      profile.platforms.each do |platform|
        service_class = PLATFORM_SERVICES[platform]
        next unless service_class

        begin
          listings_data = service_class.new(profile).fetch_listings
          process_listings(listings_data, profile)
        rescue StandardError => e
          Rails.logger.error("[Monitor] Error fetching #{platform} for profile ##{profile.id}: #{e.message}")
        end
      end

      profile.touch
    end
  end

  private

  def process_listings(listings_data, profile)
    listings_data.each do |data|
      listing = Listing.find_or_initialize_by(platform: data[:platform], external_id: data[:external_id])

      if listing.new_record?
        listing.assign_attributes(data)
        if listing.save
          ScoreListingJob.perform_later(listing.id)

          if profile.matches_listing?(listing)
            channel = profile.user.pro_or_premium? ? "email" : "email"
            alert = Alert.create!(
              user: profile.user,
              search_profile: profile,
              listing: listing,
              channel: channel
            )
            SendAlertJob.perform_later(alert.id)
          end
        end
      end
    end
  end
end
