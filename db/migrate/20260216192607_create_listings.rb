class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.string :platform
      t.string :external_id
      t.string :title
      t.text :description
      t.integer :price
      t.decimal :surface
      t.integer :rooms
      t.string :city
      t.string :postal_code
      t.string :neighborhood
      t.string :address
      t.boolean :furnished
      t.string :dpe_rating
      t.text :photos
      t.string :url
      t.decimal :latitude
      t.decimal :longitude
      t.datetime :published_at
      t.decimal :score
      t.decimal :price_per_sqm

      t.timestamps
    end
    add_index :listings, [:platform, :external_id], unique: true
  end
end
