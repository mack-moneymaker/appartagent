class CreateAutoReplies < ActiveRecord::Migration[8.1]
  def change
    create_table :auto_replies do |t|
      t.references :user, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true
      t.text :message_text
      t.datetime :sent_at
      t.string :platform
      t.string :status, default: "pending"

      t.timestamps
    end
  end
end
