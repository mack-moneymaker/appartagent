# Central registry for all supported platforms
class PlatformRegistry
  SERVICES = [LeboncoinService, SelogerService, PapService, BienciService].freeze

  def self.all
    SERVICES.map(&:platform_info)
  end

  def self.search_urls_for(search_profile)
    SERVICES.map do |service|
      info = service.platform_info
      url = service.new(search_profile).search_url
      info.merge(url: url)
    end
  end
end
