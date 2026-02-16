class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :search_profile, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true
      t.datetime :sent_at
      t.string :channel
      t.datetime :seen_at

      t.timestamps
    end
  end
end
