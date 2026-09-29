# Pedido de reposição para trocas por produto: cria um pedido rascunho com as
# novas peças (reservando o estoque, se configurado) e o endereço do pedido
# original.
#   - sem diferença a cobrar: desconto de 100% e o rascunho vira pedido;
#   - com complemento: desconto até o valor devolvido e a fatura é enviada ao
#     cliente para pagar a diferença (o pedido nasce quando ele paga).
class Shopify::ReplacementOrder
  ORDER_QUERY = <<~GRAPHQL.freeze
    query($id: ID!) {
      order(id: $id) {
        customer { id }
        shippingAddress { firstName lastName address1 address2 city province provinceCode zip countryCode phone company }
      }
    }
  GRAPHQL

  CREATE = <<~GRAPHQL.freeze
    mutation draftOrderCreate($input: DraftOrderInput!) {
      draftOrderCreate(input: $input) {
        draftOrder { id name invoiceUrl totalPriceSet { shopMoney { amount } } }
        userErrors { field message }
      }
    }
  GRAPHQL

  UPDATE = <<~GRAPHQL.freeze
    mutation draftOrderUpdate($id: ID!, $input: DraftOrderInput!) {
      draftOrderUpdate(id: $id, input: $input) {
        draftOrder { id name invoiceUrl totalPriceSet { shopMoney { amount } } }
        userErrors { field message }
      }
    }
  GRAPHQL

  COMPLETE = <<~GRAPHQL.freeze
    mutation draftOrderComplete($id: ID!) {
      draftOrderComplete(id: $id) {
        draftOrder { id order { id name } }
        userErrors { field message }
      }
    }
  GRAPHQL

  INVOICE = <<~GRAPHQL.freeze
    mutation draftOrderInvoiceSend($id: ID!) {
      draftOrderInvoiceSend(id: $id) {
        draftOrder { id invoiceUrl }
        userErrors { field message }
      }
    }
  GRAPHQL

  def initialize(client)
    @client = client
  end

  # Cria (ou atualiza) o rascunho. lines: [{ variant_id:, quantity: }]
  def draft(request:, lines:, charge: 0, reserve_until: nil, draft_id: nil)
    input = draft_input(request, lines, charge, reserve_until)
    data = if draft_id.present?
      Shopify::GraphqlCall.call(@client, UPDATE, { id: draft_id, input: input }, key: "draftOrderUpdate")
    else
      Shopify::GraphqlCall.call(@client, CREATE, { input: input }, key: "draftOrderCreate")
    end
    data["draftOrder"]
  end

  def complete(draft_id)
    Shopify::GraphqlCall.call(@client, COMPLETE, { id: draft_id }, key: "draftOrderComplete").dig("draftOrder", "order")
  end

  def send_invoice(draft_id)
    Shopify::GraphqlCall.call(@client, INVOICE, { id: draft_id }, key: "draftOrderInvoiceSend").dig("draftOrder", "invoiceUrl")
  end

  private

  def draft_input(request, lines, charge, reserve_until)
    original = Shopify::GraphqlCall.call(@client, ORDER_QUERY, { id: "gid://shopify/Order/#{request.shopify_order_id}" })["order"] || {}
    line_items = lines.map { |l| { variantId: l[:variant_id], quantity: l[:quantity] } }
    total = lines.sum { |l| l[:price].to_f * l[:quantity].to_i }
    covered = [ total - charge.to_f, 0 ].max

    input = {
      email: request.customer_email,
      lineItems: line_items,
      note: "Troca #{request.public_code} do pedido #{request.shopify_order_number}",
      tags: [ "troca", "troca-#{request.public_code}" ],
      shippingLine: { title: "Envio de troca", priceWithCurrency: { amount: "0.00", currencyCode: "BRL" } }
    }
    input[:purchasingEntity] = { customerId: original.dig("customer", "id") } if original.dig("customer", "id")
    input[:shippingAddress] = original["shippingAddress"].compact if original["shippingAddress"]
    input[:reserveInventoryUntil] = reserve_until.iso8601 if reserve_until
    if covered.positive?
      input[:appliedDiscount] = { title: "Crédito da troca", valueType: "FIXED_AMOUNT", value: covered.round(2) }
    end
    input
  end
end
