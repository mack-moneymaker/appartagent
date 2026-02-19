class CreateSavedListings < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_listings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :search_profile, foreign_key: true
      t.string :url, null: false
      t.string :platform
      t.string :title
      t.integer :price
      t.decimal :surface
      t.integer :rooms
      t.string :city
      t.string :status, default: "à voir"
      t.text :notes
      t.integer :rating
      t.decimal :price_per_sqm

      t.timestamps
    end

    add_index :saved_listings, [:user_id, :url], unique: true
  end
end
