# Vale-presente Shopify: aceita uso parcial e fica vinculado ao cliente.
class Shopify::CreateGiftCard
  MUTATION = <<~GRAPHQL.freeze
    mutation giftCardCreate($input: GiftCardCreateInput!) {
      giftCardCreate(input: $input) {
        giftCardCode
        giftCard { id }
        userErrors { field message }
      }
    }
  GRAPHQL

  def self.call(client:, amount:, expires_in:, customer_id: nil, note: nil)
    input = { initialValue: amount.to_f.round(2).to_s, expiresOn: (Date.current + expires_in).iso8601, note: note }
    input[:customerId] = customer_id if customer_id.present?
    Shopify::GraphqlCall.call(client, MUTATION, { input: input }, key: "giftCardCreate")["giftCardCode"]
  end
end
