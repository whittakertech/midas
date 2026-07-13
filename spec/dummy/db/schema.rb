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

ActiveRecord::Schema[8.1].define(version: 2026_07_13_000004) do
  create_table "midas_coins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.bigint "currency_minor", null: false
    t.bigint "resource_id", null: false
    t.string "resource_role", null: false
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id", "resource_type", "resource_role"], name: "index_midas_coins_on_resource_and_role"
    t.index ["resource_type", "resource_id"], name: "index_midas_coins_on_resource"
  end

  create_table "midas_exchanges", force: :cascade do |t|
    t.datetime "at", null: false
    t.datetime "created_at", null: false
    t.decimal "rate", precision: 24, scale: 12, null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
  end

  create_table "midas_ledger_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "kind", null: false
    t.string "name"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "slug", limit: 64
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "kind", "currency_code"], name: "index_ledger_accounts_on_owner_kind_currency", unique: true
    t.index ["owner_type", "owner_id"], name: "index_midas_ledger_accounts_on_owner"
    t.index ["slug", "currency_code"], name: "index_ledger_accounts_on_slug_currency_when_system", unique: true, where: "owner_id IS NULL"
  end

  create_table "midas_ledger_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.datetime "finalized_at"
    t.text "memo"
    t.datetime "occurred_at", null: false
    t.integer "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id"], name: "index_midas_ledger_entries_on_source"
  end

  create_table "midas_ledger_postings", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "currency_minor"
    t.string "direction", null: false
    t.integer "entry_id", null: false
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "occurred_at"], name: "index_ledger_postings_on_account_and_occurred_at"
    t.index ["account_id"], name: "index_midas_ledger_postings_on_account_id"
    t.index ["entry_id"], name: "index_midas_ledger_postings_on_entry_id"
    t.check_constraint "direction IN ('debit', 'credit')", name: "ledger_postings_direction_check"
  end

  create_table "test_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "test_orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "midas_ledger_postings", "midas_ledger_accounts", column: "account_id"
  add_foreign_key "midas_ledger_postings", "midas_ledger_entries", column: "entry_id"
end
