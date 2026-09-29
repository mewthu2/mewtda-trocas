# Cria um cupom de uso único na Shopify (valor fixo ou percentual) e devolve o
# código, ou nil se a Shopify recusar. Pode ser restrito ao cliente e combinar
# (ou não) com outros descontos.
class Shopify::CreateDiscountCode
  MUTATION = <<~GRAPHQL.freeze
    mutation discountCodeBasicCreate($basicCodeDiscount: DiscountCodeBasicInput!) {
      discountCodeBasicCreate(basicCodeDiscount: $basicCodeDiscount) {
        codeDiscountNode { id }
        userErrors { field message }
      }
    }
  GRAPHQL

  def self.call(client:, title:, percentage: nil, amount: nil, expires_in: 7.days, customer_id: nil, combines: false)
    code = "REC#{SecureRandom.alphanumeric(8).upcase}"
    starts_at = Time.current

    value = if amount.present?
      { discountAmount: { amount: amount.to_f.round(2), appliesOnEachItem: false } }
    else
      { percentage: percentage.to_f / 100 }
    end

    variables = {
      basicCodeDiscount: {
        title: title,
        code: code,
        startsAt: starts_at.iso8601,
        endsAt: (starts_at + expires_in).iso8601,
        customerGets: { value: value, items: { all: true } },
        context: customer_id.present? ? { customers: { add: [ customer_id ] } } : { all: "ALL" },
        combinesWith: { orderDiscounts: combines, productDiscounts: combines, shippingDiscounts: combines },
        usageLimit: 1
      }
    }

    Shopify::GraphqlCall.call(client, MUTATION, variables, key: "discountCodeBasicCreate")
    code
  rescue StandardError => e
    Rails.logger.error("[Shopify::CreateDiscountCode] #{e.message}")
    nil
  end
end
