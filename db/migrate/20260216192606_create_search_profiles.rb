class CreateSearchProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :search_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :city
      t.string :arrondissement
      t.integer :min_budget
      t.integer :max_budget
      t.integer :min_surface
      t.integer :max_surface
      t.integer :min_rooms
      t.integer :max_rooms
      t.boolean :furnished
      t.string :dpe_max
      t.string :property_type
      t.text :keywords
      t.text :platforms_to_monitor
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
