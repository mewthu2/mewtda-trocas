# Crédito na conta do cliente (Shopify Store Credit): uso parcial, com validade.
class Shopify::CreditStoreCredit
  MUTATION = <<~GRAPHQL.freeze
    mutation storeCreditAccountCredit($id: ID!, $creditInput: StoreCreditAccountCreditInput!) {
      storeCreditAccountCredit(id: $id, creditInput: $creditInput) {
        storeCreditAccountTransaction { id }
        userErrors { field message }
      }
    }
  GRAPHQL

  def self.call(client:, customer_id:, amount:, expires_in:)
    raise Shopify::GraphqlCall::Error, "pedido sem cliente cadastrado na Shopify" if customer_id.blank?

    Shopify::GraphqlCall.call(client, MUTATION, {
      id: customer_id,
      creditInput: {
        creditAmount: { amount: amount.to_f.round(2).to_s, currencyCode: "BRL" },
        expiresAt: (Time.current + expires_in).iso8601
      }
    }, key: "storeCreditAccountCredit").dig("storeCreditAccountTransaction", "id")
  end
end
