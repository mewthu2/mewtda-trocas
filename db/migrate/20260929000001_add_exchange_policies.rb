# Políticas configuráveis de troca/devolução: prazos, elegibilidade, motivos,
# resultados, frete reverso (contrato Correios), diferença de preço, estoque,
# aprovação, reembolso, crédito e comunicação.
class AddExchangePolicies < ActiveRecord::Migration[8.1]
  def change
    # Envio de e-mails pela SES, configurado aqui (domínio + DKIM).
    change_table :clients, bulk: true do |t|
      t.string :ses_dkim_tokens, array: true, default: [], null: false
      t.datetime :ses_verified_at
      t.string :email_from_name
      t.string :email_from_local, default: "naoresponda", null: false
      t.string :email_reply_to
    end

    change_table :exchange_configs, bulk: true do |t|
      # Prazo
      t.string :window_base, default: "delivery", null: false
      t.integer :defect_window_days, default: 90, null: false
      # Condições da troca voluntária
      t.boolean :require_original_tag, default: false, null: false
      t.boolean :require_accessories, default: false, null: false
      t.boolean :require_packaging, default: false, null: false
      # Frete reverso
      t.string :return_modes, array: true, default: [ "agencia" ], null: false
      t.text :store_drop_off_addresses
      t.boolean :free_shipping_first_attempt, default: true, null: false
      t.decimal :free_shipping_above, precision: 10, scale: 2
      t.decimal :customer_shipping_flat_fee, precision: 10, scale: 2
      # Diferença de preço
      t.string :price_basis, default: "paid", null: false
      t.string :higher_price_action, default: "charge", null: false
      t.string :lower_price_action, default: "credit", null: false
      # Estoque
      t.string :reserve_stock_on, default: "approval", null: false
      t.integer :reserve_hours, default: 72, null: false
      # Aprovação
      t.boolean :auto_approve, default: false, null: false
      t.decimal :auto_approve_max_value, precision: 10, scale: 2
      t.integer :abuse_max_requests, default: 3, null: false
      t.integer :abuse_window_days, default: 90, null: false
      t.string :resolve_on, default: "approval", null: false
      # Reembolso
      t.boolean :refund_original_shipping, default: false, null: false
      # Crédito
      t.string :credit_type, default: "coupon", null: false
      t.boolean :credit_combines_with_discounts, default: false, null: false
      t.boolean :credit_link_customer, default: true, null: false
      # Comunicação
      t.boolean :email_enabled, default: true, null: false
      t.boolean :whatsapp_enabled, default: false, null: false
      t.boolean :tracking_page_enabled, default: true, null: false
      t.integer :analysis_sla_days, default: 2, null: false
      t.integer :refund_sla_days, default: 7, null: false
      %w[label_issued received refunded].each do |kind|
        t.string :"#{kind}_email_subject"
        t.text :"#{kind}_email_body"
      end
      %w[requested approved rejected label_issued received completed refunded].each do |kind|
        t.text :"#{kind}_whatsapp_body"
      end
    end

    create_table :exchange_reasons do |t|
      t.references :exchange_config, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.string :category, null: false, default: "voluntary"
      t.boolean :active, default: true, null: false
      t.string :resolutions, array: true, default: [], null: false
      t.boolean :requires_photo, default: false, null: false
      t.boolean :manual_review, default: false, null: false
      t.string :shipping_payer, default: "store", null: false
      t.text :questions
      t.integer :position, default: 0, null: false
      t.timestamps
      t.index %i[exchange_config_id key], unique: true
    end

    # Exceções de prazo e exclusões de elegibilidade.
    create_table :exchange_rules do |t|
      t.references :exchange_config, null: false, foreign_key: true
      t.string :rule_type, null: false
      t.string :target, null: false
      t.string :value
      t.integer :days
      t.date :starts_on
      t.date :ends_on
      t.string :note
      t.timestamps
    end

    create_table :carrier_contracts do |t|
      t.references :exchange_config, null: false, foreign_key: true, index: { unique: true }
      t.string :carrier, default: "correios", null: false
      t.boolean :active, default: false, null: false
      t.string :username
      t.string :access_code
      t.string :posting_card
      t.string :contract_number
      t.string :administrative_code
      t.string :default_service, default: "03301", null: false
      t.string :sender_name
      t.string :sender_document
      t.string :sender_phone
      t.string :sender_email
      t.string :sender_zip
      t.string :sender_street
      t.string :sender_number
      t.string :sender_complement
      t.string :sender_district
      t.string :sender_city
      t.string :sender_state
      t.integer :package_weight_g, default: 500, null: false
      t.integer :package_length_cm, default: 30, null: false
      t.integer :package_width_cm, default: 20, null: false
      t.integer :package_height_cm, default: 10, null: false
      t.integer :authorization_days, default: 15, null: false
      t.text :manual_instructions
      t.timestamps
    end

    create_table :shipping_rules do |t|
      t.references :exchange_config, null: false, foreign_key: true
      t.string :zip_start
      t.string :zip_end
      t.integer :max_weight_g
      t.string :service_code, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    change_table :exchange_requests, bulk: true do |t|
      t.string :public_code
      t.string :customer_phone
      t.string :customer_zip
      t.string :shopify_customer_id
      t.datetime :delivered_at
      t.string :return_mode
      t.string :shipping_payer
      t.decimal :shipping_cost, precision: 10, scale: 2
      t.string :return_service
      t.string :return_authorization_code
      t.string :return_tracking_code
      t.datetime :return_expires_at
      t.boolean :auto_approved, default: false, null: false
      t.boolean :flagged_for_review, default: false, null: false
      t.string :review_reasons, array: true, default: [], null: false
      t.text :rejection_reason
      t.decimal :price_difference, precision: 10, scale: 2, default: 0, null: false
      t.string :credit_kind
      t.decimal :credit_amount, precision: 10, scale: 2
      t.string :replacement_draft_order_id
      t.string :replacement_order_name
      t.string :invoice_url
      t.datetime :stock_reserved_until
      t.jsonb :refund_details, default: {}, null: false
      t.datetime :approved_at
      t.datetime :received_at
      t.datetime :completed_at
      t.index :public_code, unique: true
    end

    change_table :exchange_request_items, bulk: true do |t|
      t.string :resolution
      t.string :reason_label
      t.jsonb :answers, default: {}, null: false
      t.boolean :conditions_confirmed, default: false, null: false
      t.string :shopify_line_item_id
      t.string :shopify_product_id
      t.string :shopify_variant_id
      t.decimal :current_price, precision: 10, scale: 2
      t.integer :weight_g
      t.string :new_variant_id
      t.string :new_variant_title
      t.decimal :new_variant_price, precision: 10, scale: 2
    end

    create_table :exchange_events do |t|
      t.references :exchange_request, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :kind, null: false
      t.text :message, null: false
      t.boolean :public, default: false, null: false
      t.timestamps
    end

    create_table :exchange_refunds do |t|
      t.references :exchange_request, null: false, foreign_key: true
      t.string :method, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: "pending", null: false
      t.string :shopify_refund_id
      t.text :notes
      t.timestamps
    end
  end
end
