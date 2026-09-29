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

ActiveRecord::Schema[8.1].define(version: 2026_09_28_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "clients", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.boolean "active", default: true
    t.string "shopify_shop_url"
    t.string "shopify_access_token"
    t.string "zapi_instance_id"
    t.string "zapi_instance_token"
    t.string "zapi_client_token"
    t.string "site_url"
    t.string "email_sending_domain"
    t.string "ses_verification_status", default: "unverified", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shopify_shop_url"], name: "index_clients_on_shopify_shop_url", unique: true
  end

  create_table "exchange_configs", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.boolean "active", default: false, null: false
    t.string "company_name"
    t.string "accent_color", default: "#7c3aed", null: false
    t.text "instructions"
    t.integer "return_window_days", default: 7, null: false
    t.integer "coupon_validity_days", default: 30, null: false
    t.string "slug", null: false
    t.string "requested_email_subject"
    t.text "requested_email_body"
    t.string "approved_email_subject"
    t.text "approved_email_body"
    t.string "rejected_email_subject"
    t.text "rejected_email_body"
    t.string "completed_email_subject"
    t.text "completed_email_body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_exchange_configs_on_client_id", unique: true
    t.index ["slug"], name: "index_exchange_configs_on_slug", unique: true
  end

  create_table "exchange_request_items", force: :cascade do |t|
    t.bigint "exchange_request_id", null: false
    t.string "sku"
    t.string "product_name", null: false
    t.string "variant_title"
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "kind", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_request_id"], name: "index_exchange_request_items_on_exchange_request_id"
  end

  create_table "exchange_requests", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "shopify_order_id", null: false
    t.string "shopify_order_number", null: false
    t.string "customer_email", null: false
    t.string "customer_name"
    t.integer "status", default: 0, null: false
    t.string "coupon_code"
    t.text "internal_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "status"], name: "index_exchange_requests_on_client_id_and_status"
    t.index ["client_id"], name: "index_exchange_requests_on_client_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.bigint "profile_id"
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_users_on_client_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["profile_id"], name: "index_users_on_profile_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "exchange_configs", "clients"
  add_foreign_key "exchange_request_items", "exchange_requests"
  add_foreign_key "exchange_requests", "clients"
end
