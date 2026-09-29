# Reembolso pela Shopify na forma de pagamento original: pede à Shopify a
# sugestão de transações (suggestedRefund) para os itens e o frete, e cria o
# refund com elas. Gateways sem estorno automático (Pix/boleto manuais) ficam
# para a equipe registrar o andamento.
class Shopify::CreateRefund
  SUGGEST = <<~GRAPHQL.freeze
    query($id: ID!, $items: [RefundLineItemInput!], $shipping: Money) {
      order(id: $id) {
        suggestedRefund(refundLineItems: $items, shippingAmount: $shipping, suggestFullRefund: false) {
          amountSet { shopMoney { amount } }
          suggestedTransactions { gateway kind amountSet { shopMoney { amount } } parentTransaction { id } }
        }
      }
    }
  GRAPHQL

  MUTATION = <<~GRAPHQL.freeze
    mutation refundCreate($input: RefundInput!) {
      refundCreate(input: $input) {
        refund { id totalRefundedSet { shopMoney { amount } } }
        userErrors { field message }
      }
    }
  GRAPHQL

  Result = Struct.new(:refund_id, :amount, :gateway, keyword_init: true)

  # items: [{ line_item_id:, quantity: }]
  def self.call(client:, order_id:, items:, shipping_amount: 0, deduct: 0, note: nil)
    order_gid = order_id.to_s.start_with?("gid://") ? order_id : "gid://shopify/Order/#{order_id}"
    line_items = items.map { |i| { lineItemId: i[:line_item_id], quantity: i[:quantity], restockType: "NO_RESTOCK" } }

    suggestion = Shopify::GraphqlCall.call(client, SUGGEST, {
      id: order_gid, items: line_items, shipping: shipping_amount.to_f.positive? ? shipping_amount.to_f.round(2).to_s : nil
    }).dig("order", "suggestedRefund")

    remaining_deduction = deduct.to_f
    transactions = Array(suggestion["suggestedTransactions"]).filter_map do |t|
      amount = t.dig("amountSet", "shopMoney", "amount").to_f
      cut = [ remaining_deduction, amount ].min
      remaining_deduction -= cut
      amount -= cut
      next if amount <= 0

      { orderId: order_gid, parentId: t.dig("parentTransaction", "id"), gateway: t["gateway"], kind: "REFUND",
        amount: amount.round(2).to_s }
    end

    input = { orderId: order_gid, refundLineItems: line_items, transactions: transactions, note: note, notify: true }
    input[:shipping] = { amount: shipping_amount.to_f.round(2).to_s } if shipping_amount.to_f.positive?

    refund = Shopify::GraphqlCall.call(client, MUTATION, { input: input }, key: "refundCreate")["refund"]
    Result.new(refund_id: refund["id"], amount: refund.dig("totalRefundedSet", "shopMoney", "amount").to_f,
               gateway: transactions.first&.dig(:gateway))
  end
end
