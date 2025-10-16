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

ActiveRecord::Schema[8.0].define(version: 2025_10_15_173602) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "test_orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wt_midas_coins", force: :cascade do |t|
    t.string "resource_type", null: false
    t.bigint "resource_id", null: false
    t.string "resource_label", null: false
    t.string "currency_code", limit: 3, null: false
    t.bigint "currency_minor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id", "resource_type", "resource_label"], name: "index_wt_midas_coins_on_resource_and_label"
    t.index ["resource_type", "resource_id"], name: "index_wt_midas_coins_on_resource"
  end
end
