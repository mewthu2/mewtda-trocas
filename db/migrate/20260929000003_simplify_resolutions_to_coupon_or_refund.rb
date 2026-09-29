# Aprovada a solicitação, o resultado é só cupom ou devolução do dinheiro
# (estorno, Pix ou transferência feitos pela equipe, com comprovante). Sai o
# pedido de reposição na Shopify e, com ele, diferença de preço e reserva de estoque.
class SimplifyResolutionsToCouponOrRefund < ActiveRecord::Migration[8.1]
  COUPON_RESOLUTIONS = %w[same_variant other_variant other_product store_credit].freeze

  def up
    add_column :exchange_configs, :refund_methods, :string, array: true, default: %w[estorno pix transferencia], null: false
    add_column :exchange_requests, :refund_method, :string

    COUPON_RESOLUTIONS.each do |old|
      execute <<~SQL
        UPDATE exchange_reasons
        SET resolutions = array_append(array_remove(resolutions, '#{old}'), 'coupon')
        WHERE '#{old}' = ANY(resolutions)
      SQL
    end
    execute "UPDATE exchange_reasons SET resolutions = ARRAY(SELECT DISTINCT unnest(resolutions))"
    execute "UPDATE exchange_request_items SET resolution = 'coupon' WHERE resolution IN (#{COUPON_RESOLUTIONS.map { |r| "'#{r}'" }.join(', ')})"
    execute "UPDATE exchange_refunds SET method = 'estorno' WHERE method IN ('card', 'other')"
    execute "UPDATE exchange_refunds SET method = 'transferencia' WHERE method = 'boleto'"

    remove_columns :exchange_configs, :price_basis, :higher_price_action, :lower_price_action, :reserve_stock_on,
                   :reserve_hours, :credit_type, :credit_combines_with_discounts
    remove_columns :exchange_requests, :price_difference, :credit_kind, :replacement_draft_order_id,
                   :replacement_order_name, :invoice_url, :stock_reserved_until
    remove_columns :exchange_request_items, :current_price, :new_variant_id, :new_variant_title, :new_variant_price
    remove_column :exchange_refunds, :shopify_refund_id
    add_column :exchange_configs, :coupon_combines_with_discounts, :boolean, default: false, null: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
