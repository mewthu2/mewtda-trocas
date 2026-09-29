module Shopify
  module AdminSession
    module_function

    def rest(client)
      ShopifyAPI::Clients::Rest::Admin.new(session: session(client))
    end

    def graphql(client)
      ShopifyAPI::Clients::Graphql::Admin.new(session: session(client))
    end

    def session(client)
      ShopifyAPI::Auth::Session.new(shop: client.shopify_shop_url, access_token: client.shopify_access_token)
    end
  end
end
