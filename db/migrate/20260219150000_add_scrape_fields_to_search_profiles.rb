class AddScrapeFieldsToSearchProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :search_profiles, :needs_scrape, :boolean, default: true
    add_column :search_profiles, :scraped_at, :datetime
  end
end
