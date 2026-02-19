class AddTransactionTypeAndGeoToSearchProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :search_profiles, :transaction_type, :string, default: "rental"
    add_column :search_profiles, :postal_code, :string
    add_column :search_profiles, :latitude, :decimal
    add_column :search_profiles, :longitude, :decimal
    add_column :search_profiles, :last_checked_at, :datetime
  end
end
