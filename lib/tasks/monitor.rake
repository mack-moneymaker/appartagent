namespace :monitor do
  desc "Run platform monitoring (can be called via cron as fallback to SolidQueue)"
  task run: :environment do
    MonitorPlatformsJob.perform_now
  end

  desc "Test a single platform scraper"
  task :test, [:platform] => :environment do |_t, args|
    platform = args[:platform] || "pap"
    profile = SearchProfile.where(active: true).first

    unless profile
      puts "No active search profile found. Create one first."
      next
    end

    service_class = MonitorPlatformsJob::PLATFORM_SERVICES[platform]
    unless service_class
      puts "Unknown platform: #{platform}. Available: #{MonitorPlatformsJob::PLATFORM_SERVICES.keys.join(', ')}"
      next
    end

    puts "Testing #{platform} with profile ##{profile.id} (#{profile.city})..."
    listings = service_class.new(profile).fetch_listings
    puts "Found #{listings.size} listings:"
    listings.first(5).each do |l|
      puts "  - #{l[:title]} | #{l[:price]}€ | #{l[:surface]}m² | #{l[:url]}"
    end
  end
end
