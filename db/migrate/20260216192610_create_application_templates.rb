class CreateApplicationTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :application_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :content

      t.timestamps
    end
  end
end
