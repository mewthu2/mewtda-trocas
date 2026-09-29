# Busca o pedido na Shopify pelo número (#1001) e confere o e-mail — é a única
# "autenticação" do cliente final na página pública. Traz o que as regras de
# troca precisam: entrega, tags, coleções, canal e peso.
class Shopify::FindOrderForExchange
  QUERY = <<~GRAPHQL.freeze
    query($q: String!) {
      orders(first: 1, query: $q) {
        nodes {
          id legacyResourceId name email phone createdAt cancelledAt tags sourceName paymentGatewayNames
          customer { id }
          shippingAddress { zip phone }
          totalShippingPriceSet { shopMoney { amount } }
          fulfillments { createdAt deliveredAt }
          lineItems(first: 100) {
            nodes {
              id title variantTitle sku quantity currentQuantity
              discountedUnitPriceAfterAllDiscountsSet { shopMoney { amount } }
              variant { id inventoryItem { measurement { weight { unit value } } } }
              product { id tags collections(first: 25) { nodes { id title } } }
            }
          }
        }
      }
    }
  GRAPHQL

  WEIGHT_TO_GRAMS = { "GRAMS" => 1, "KILOGRAMS" => 1000, "OUNCES" => 28.3495, "POUNDS" => 453.592 }.freeze

  def self.call(client:, order_number:, email:)
    return nil unless client.shopify_configured?

    name = order_number.to_s.strip.delete_prefix("#")
    return nil if name.blank?

    response = Shopify::AdminSession.graphql(client).query(query: QUERY, variables: { q: "name:\"##{name}\"" })
    if response.body["errors"].present?
      Rails.logger.error("[Shopify::FindOrderForExchange] #{response.body['errors'].inspect}")
      return nil
    end

    shopify_order = Array(response.body.dig("data", "orders", "nodes")).first
    return nil unless shopify_order
    return nil unless shopify_order["email"].to_s.casecmp(email.to_s.strip).zero?

    normalize(shopify_order)
  rescue StandardError => e
    Rails.logger.error("[Shopify::FindOrderForExchange] #{e.class} #{e.message}")
    nil
  end

  def self.normalize(order)
    fulfillments = Array(order["fulfillments"])
    shipped = fulfillments.map { |f| f["createdAt"] }.compact.max
    delivered = fulfillments.map { |f| f["deliveredAt"] }.compact.max

    {
      id: order["legacyResourceId"].to_s,
      gid: order["id"],
      number: order["name"],
      email: order["email"],
      phone: order["phone"].presence || order.dig("shippingAddress", "phone"),
      zip: order.dig("shippingAddress", "zip").to_s.gsub(/\D/, "").presence,
      customer_id: order.dig("customer", "id"),
      created_at: parse_time(order["createdAt"]),
      cancelled: order["cancelledAt"].present?,
      fulfilled_at: parse_time(shipped),
      delivered_at: parse_time(delivered),
      tags: Array(order["tags"]),
      channel: order["sourceName"],
      gateways: Array(order["paymentGatewayNames"]),
      shipping_paid: order.dig("totalShippingPriceSet", "shopMoney", "amount").to_f,
      items: Array(order.dig("lineItems", "nodes")).filter_map { |line_item| normalize_item(line_item) }
    }
  end

  def self.normalize_item(line_item)
    quantity = (line_item["currentQuantity"] || line_item["quantity"]).to_i
    return nil if quantity <= 0

    variant = line_item["variant"] || {}
    product = line_item["product"] || {}
    weight = variant.dig("inventoryItem", "measurement", "weight")

    {
      line_item_id: line_item["id"],
      product_id: product["id"],
      variant_id: variant["id"],
      sku: line_item["sku"],
      product_name: line_item["title"],
      variant_title: line_item["variantTitle"],
      quantity: quantity,
      price: line_item.dig("discountedUnitPriceAfterAllDiscountsSet", "shopMoney", "amount").to_f,
      weight_g: weight && (weight["value"].to_f * WEIGHT_TO_GRAMS.fetch(weight["unit"], 1)).round,
      product_tags: Array(product["tags"]),
      collections: Array(product.dig("collections", "nodes")).map { |c| { id: c["id"], title: c["title"] } }
    }
  end

  def self.parse_time(value)
    value.present? ? Time.zone.parse(value) : nil
  end
end
