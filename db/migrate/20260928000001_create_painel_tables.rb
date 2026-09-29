# Tabelas do app, com a mesma estrutura das do mewtda-painel (o banco de
# produção é separado). Tudo é if_not_exists.
class CreatePainelTables < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles, if_not_exists: true do |t|
      t.string :name
      t.timestamps
    end

    create_table :clients, if_not_exists: true do |t|
      t.string :name
      t.string :email
      t.boolean :active, default: true
      t.string :shopify_shop_url, index: { unique: true }
      t.string :shopify_access_token
      t.string :zapi_instance_id
      t.string :zapi_instance_token
      t.string :zapi_client_token
      t.string :site_url
      t.string :email_sending_domain
      t.string :ses_verification_status, default: "unverified", null: false
      t.timestamps
    end

    create_table :users, if_not_exists: true do |t|
      t.string :name
      t.string :phone
      t.string :email, default: "", null: false, index: { unique: true }
      t.string :encrypted_password, default: "", null: false
      t.string :reset_password_token, index: { unique: true }
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.references :profile
      t.references :client
      t.timestamps
    end

    create_table :exchange_configs, if_not_exists: true do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.boolean :active, default: false, null: false
      t.string :company_name
      t.string :accent_color, default: "#7c3aed", null: false
      t.text :instructions
      t.integer :return_window_days, default: 7, null: false
      t.integer :coupon_validity_days, default: 30, null: false
      t.string :slug, null: false, index: { unique: true }
      %w[requested approved rejected completed].each do |kind|
        t.string :"#{kind}_email_subject"
        t.text :"#{kind}_email_body"
      end
      t.timestamps
    end

    create_table :exchange_requests, if_not_exists: true do |t|
      t.references :client, null: false, foreign_key: true
      t.string :shopify_order_id, null: false
      t.string :shopify_order_number, null: false
      t.string :customer_email, null: false
      t.string :customer_name
      t.integer :status, default: 0, null: false
      t.string :coupon_code
      t.text :internal_notes
      t.timestamps
      t.index %i[client_id status]
    end

    create_table :exchange_request_items, if_not_exists: true do |t|
      t.references :exchange_request, null: false, foreign_key: true
      t.string :sku
      t.string :product_name, null: false
      t.string :variant_title
      t.integer :quantity, default: 1, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :kind, null: false
      t.text :reason
      t.timestamps
    end

    create_table :active_storage_blobs, if_not_exists: true do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum
      t.datetime :created_at, null: false
    end

    create_table :active_storage_attachments, if_not_exists: true do |t|
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs }
      t.datetime :created_at, null: false
      t.index %i[record_type record_id name blob_id], name: :index_active_storage_attachments_uniqueness, unique: true
    end

    create_table :active_storage_variant_records, if_not_exists: true do |t|
      t.belongs_to :blob, null: false, index: false, foreign_key: { to_table: :active_storage_blobs }
      t.string :variation_digest, null: false
      t.index %i[blob_id variation_digest], name: :index_active_storage_variant_records_uniqueness, unique: true
    end
  end
end
