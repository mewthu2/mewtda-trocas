# Cria um cupom de uso único na Shopify (valor fixo ou percentual) e devolve o
# código, ou nil se a Shopify recusar.
class Shopify::CreateDiscountCode
  MUTATION = <<~GRAPHQL.freeze
    mutation discountCodeBasicCreate($basicCodeDiscount: DiscountCodeBasicInput!) {
      discountCodeBasicCreate(basicCodeDiscount: $basicCodeDiscount) {
        codeDiscountNode { id }
        userErrors { field message }
      }
    }
  GRAPHQL

  def self.call(client:, title:, percentage: nil, amount: nil, expires_in: 7.days)
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
        context: { all: "ALL" },
        usageLimit: 1
      }
    }

    response = Shopify::AdminSession.graphql(client).query(query: MUTATION, variables: variables)
    errors = Array(response.body["errors"]) + Array(response.body.dig("data", "discountCodeBasicCreate", "userErrors"))
    if errors.any?
      Rails.logger.error("[Shopify::CreateDiscountCode] #{errors.inspect}")
      return nil
    end

    code
  end
end
