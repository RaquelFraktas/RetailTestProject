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

ActiveRecord::Schema[7.1].define(version: 2026_10_18_194935) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "alerts", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.bigint "tracking_event_id", null: false
    t.bigint "previous_tracking_event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_alerts_on_brand_id"
    t.index ["previous_tracking_event_id"], name: "index_alerts_on_previous_tracking_event_id"
    t.index ["product_id"], name: "index_alerts_on_product_id"
    t.index ["store_id"], name: "index_alerts_on_store_id"
    t.index ["tracking_event_id"], name: "index_alerts_on_tracking_event_id", unique: true
  end

  create_table "brands", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_products_on_brand_id"
  end

  create_table "stores", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tracking_events", force: :cascade do |t|
    t.boolean "inventory_present"
    t.bigint "product_id", null: false
    t.bigint "store_id", null: false
    t.datetime "event_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price", precision: 10, scale: 2
    t.index ["product_id"], name: "index_tracking_events_on_product_id"
    t.index ["store_id", "product_id", "event_time"], name: "idx_on_store_id_product_id_event_time_31e9176147"
    t.index ["store_id"], name: "index_tracking_events_on_store_id"
  end

  add_foreign_key "alerts", "brands"
  add_foreign_key "alerts", "products"
  add_foreign_key "alerts", "stores"
  add_foreign_key "alerts", "tracking_events", column: "previous_tracking_event_id", on_delete: :cascade
  add_foreign_key "alerts", "tracking_events", on_delete: :cascade
  add_foreign_key "products", "brands"
  add_foreign_key "tracking_events", "products"
  add_foreign_key "tracking_events", "stores"
end
