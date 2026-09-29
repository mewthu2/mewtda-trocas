# Apps privados/custom: cada Client guarda o próprio access token, então
# api_key/secret aqui só existem porque o Context exige.
ShopifyAPI::Context.setup(
  api_key: ENV.fetch("SHOPIFY_API_KEY", "private-app"),
  api_secret_key: ENV.fetch("SHOPIFY_API_SECRET", "private-app"),
  scope: "read_orders,write_discounts",
  is_embedded: false,
  api_version: ENV.fetch("SHOPIFY_API_VERSION", "2026-07"),
  is_private: true,
  logger: Rails.logger
)
