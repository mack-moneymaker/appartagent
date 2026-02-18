# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_16_192610) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "alerts", force: :cascade do |t|
    t.string "channel"
    t.datetime "created_at", null: false
    t.bigint "listing_id", null: false
    t.bigint "search_profile_id", null: false
    t.datetime "seen_at"
    t.datetime "sent_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["listing_id"], name: "index_alerts_on_listing_id"
    t.index ["search_profile_id"], name: "index_alerts_on_search_profile_id"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "application_templates", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_application_templates_on_user_id"
  end

  create_table "auto_replies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "listing_id", null: false
    t.text "message_text"
    t.string "platform"
    t.datetime "sent_at"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["listing_id"], name: "index_auto_replies_on_listing_id"
    t.index ["user_id"], name: "index_auto_replies_on_user_id"
  end

  create_table "listings", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "dpe_rating"
    t.string "external_id"
    t.boolean "furnished"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "neighborhood"
    t.text "photos"
    t.string "platform"
    t.string "postal_code"
    t.integer "price"
    t.decimal "price_per_sqm"
    t.datetime "published_at"
    t.integer "rooms"
    t.decimal "score"
    t.decimal "surface"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["platform", "external_id"], name: "index_listings_on_platform_and_external_id", unique: true
  end

  create_table "search_profiles", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "arrondissement"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "dpe_max"
    t.boolean "furnished"
    t.text "keywords"
    t.integer "max_budget"
    t.integer "max_rooms"
    t.integer "max_surface"
    t.integer "min_budget"
    t.integer "min_rooms"
    t.integer "min_surface"
    t.text "platforms_to_monitor"
    t.string "property_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_search_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.string "phone"
    t.string "plan", default: "free"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "alerts", "listings"
  add_foreign_key "alerts", "search_profiles"
  add_foreign_key "alerts", "users"
  add_foreign_key "application_templates", "users"
  add_foreign_key "auto_replies", "listings"
  add_foreign_key "auto_replies", "users"
  add_foreign_key "search_profiles", "users"
end
