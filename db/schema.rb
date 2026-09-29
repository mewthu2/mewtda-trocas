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

ActiveRecord::Schema[8.1].define(version: 2026_09_29_000004) do
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

  create_table "carrier_contracts", force: :cascade do |t|
    t.bigint "exchange_config_id", null: false
    t.string "carrier", default: "correios", null: false
    t.boolean "active", default: false, null: false
    t.string "username"
    t.string "access_code"
    t.string "posting_card"
    t.string "contract_number"
    t.string "administrative_code"
    t.string "default_service", default: "03301", null: false
    t.string "sender_name"
    t.string "sender_document"
    t.string "sender_phone"
    t.string "sender_email"
    t.string "sender_zip"
    t.string "sender_street"
    t.string "sender_number"
    t.string "sender_complement"
    t.string "sender_district"
    t.string "sender_city"
    t.string "sender_state"
    t.integer "package_weight_g", default: 500, null: false
    t.integer "package_length_cm", default: 30, null: false
    t.integer "package_width_cm", default: 20, null: false
    t.integer "package_height_cm", default: 10, null: false
    t.integer "authorization_days", default: 15, null: false
    t.text "manual_instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_config_id"], name: "index_carrier_contracts_on_exchange_config_id", unique: true
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
    t.string "email_domain_status", default: "unverified", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_domain_verified_at"
    t.string "email_from_name"
    t.string "email_from_local", default: "trocas", null: false
    t.string "email_reply_to"
    t.text "email_dns_records"
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
    t.string "window_base", default: "delivery", null: false
    t.integer "defect_window_days", default: 90, null: false
    t.boolean "require_original_tag", default: false, null: false
    t.boolean "require_accessories", default: false, null: false
    t.boolean "require_packaging", default: false, null: false
    t.string "return_modes", default: ["agencia"], null: false, array: true
    t.text "store_drop_off_addresses"
    t.boolean "free_shipping_first_attempt", default: true, null: false
    t.decimal "free_shipping_above", precision: 10, scale: 2
    t.decimal "customer_shipping_flat_fee", precision: 10, scale: 2
    t.boolean "auto_approve", default: false, null: false
    t.decimal "auto_approve_max_value", precision: 10, scale: 2
    t.integer "abuse_max_requests", default: 3, null: false
    t.integer "abuse_window_days", default: 90, null: false
    t.string "resolve_on", default: "approval", null: false
    t.boolean "refund_original_shipping", default: false, null: false
    t.boolean "credit_link_customer", default: true, null: false
    t.boolean "email_enabled", default: true, null: false
    t.boolean "whatsapp_enabled", default: false, null: false
    t.boolean "tracking_page_enabled", default: true, null: false
    t.integer "analysis_sla_days", default: 2, null: false
    t.integer "refund_sla_days", default: 7, null: false
    t.string "label_issued_email_subject"
    t.text "label_issued_email_body"
    t.string "received_email_subject"
    t.text "received_email_body"
    t.string "refunded_email_subject"
    t.text "refunded_email_body"
    t.text "requested_whatsapp_body"
    t.text "approved_whatsapp_body"
    t.text "rejected_whatsapp_body"
    t.text "label_issued_whatsapp_body"
    t.text "received_whatsapp_body"
    t.text "completed_whatsapp_body"
    t.text "refunded_whatsapp_body"
    t.string "support_email"
    t.string "support_whatsapp"
    t.string "support_hours"
    t.string "refund_methods", default: ["estorno", "pix", "transferencia"], null: false, array: true
    t.boolean "coupon_combines_with_discounts", default: false, null: false
    t.index ["client_id"], name: "index_exchange_configs_on_client_id", unique: true
    t.index ["slug"], name: "index_exchange_configs_on_slug", unique: true
  end

  create_table "exchange_events", force: :cascade do |t|
    t.bigint "exchange_request_id", null: false
    t.bigint "user_id"
    t.string "kind", null: false
    t.text "message", null: false
    t.boolean "public", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_request_id"], name: "index_exchange_events_on_exchange_request_id"
    t.index ["user_id"], name: "index_exchange_events_on_user_id"
  end

  create_table "exchange_reasons", force: :cascade do |t|
    t.bigint "exchange_config_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "category", default: "voluntary", null: false
    t.boolean "active", default: true, null: false
    t.string "resolutions", default: [], null: false, array: true
    t.boolean "requires_photo", default: false, null: false
    t.boolean "manual_review", default: false, null: false
    t.string "shipping_payer", default: "store", null: false
    t.text "questions"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_config_id", "key"], name: "index_exchange_reasons_on_exchange_config_id_and_key", unique: true
    t.index ["exchange_config_id"], name: "index_exchange_reasons_on_exchange_config_id"
  end

  create_table "exchange_refunds", force: :cascade do |t|
    t.bigint "exchange_request_id", null: false
    t.string "method", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_request_id"], name: "index_exchange_refunds_on_exchange_request_id"
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
    t.string "resolution"
    t.string "reason_label"
    t.jsonb "answers", default: {}, null: false
    t.boolean "conditions_confirmed", default: false, null: false
    t.string "shopify_line_item_id"
    t.string "shopify_product_id"
    t.string "shopify_variant_id"
    t.integer "weight_g"
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
    t.string "public_code"
    t.string "customer_phone"
    t.string "customer_zip"
    t.string "shopify_customer_id"
    t.datetime "delivered_at"
    t.string "return_mode"
    t.string "shipping_payer"
    t.decimal "shipping_cost", precision: 10, scale: 2
    t.string "return_service"
    t.string "return_authorization_code"
    t.string "return_tracking_code"
    t.datetime "return_expires_at"
    t.boolean "auto_approved", default: false, null: false
    t.boolean "flagged_for_review", default: false, null: false
    t.string "review_reasons", default: [], null: false, array: true
    t.text "rejection_reason"
    t.decimal "credit_amount", precision: 10, scale: 2
    t.jsonb "refund_details", default: {}, null: false
    t.datetime "approved_at"
    t.datetime "received_at"
    t.datetime "completed_at"
    t.string "refund_method"
    t.index ["client_id", "status"], name: "index_exchange_requests_on_client_id_and_status"
    t.index ["client_id"], name: "index_exchange_requests_on_client_id"
    t.index ["public_code"], name: "index_exchange_requests_on_public_code", unique: true
  end

  create_table "exchange_rules", force: :cascade do |t|
    t.bigint "exchange_config_id", null: false
    t.string "rule_type", null: false
    t.string "target", null: false
    t.string "value"
    t.integer "days"
    t.date "starts_on"
    t.date "ends_on"
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_config_id"], name: "index_exchange_rules_on_exchange_config_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shipping_rules", force: :cascade do |t|
    t.bigint "exchange_config_id", null: false
    t.string "zip_start"
    t.string "zip_end"
    t.integer "max_weight_g"
    t.string "service_code", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_config_id"], name: "index_shipping_rules_on_exchange_config_id"
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
  add_foreign_key "carrier_contracts", "exchange_configs"
  add_foreign_key "exchange_configs", "clients"
  add_foreign_key "exchange_events", "exchange_requests"
  add_foreign_key "exchange_events", "users"
  add_foreign_key "exchange_reasons", "exchange_configs"
  add_foreign_key "exchange_refunds", "exchange_requests"
  add_foreign_key "exchange_request_items", "exchange_requests"
  add_foreign_key "exchange_requests", "clients"
  add_foreign_key "exchange_rules", "exchange_configs"
  add_foreign_key "shipping_rules", "exchange_configs"
end
