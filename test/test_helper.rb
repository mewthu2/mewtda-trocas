ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Troca temporariamente um método de classe (Minitest 6 não traz mais #stub).
    def with_stubbed(klass, method_name, returns = nil, &block)
      original = klass.method(method_name)
      replacement = returns.respond_to?(:call) ? returns : ->(*, **) { returns }
      klass.define_singleton_method(method_name, &replacement)
      block.call
    ensure
      klass.define_singleton_method(method_name, original)
    end

    def create_client(name: "Loja Teste", **attrs)
      Client.create!(name: name, email: "contato@#{name.parameterize}.com", **attrs)
    end

    def create_config(client, **attrs)
      client.create_exchange_config!({ active: true, company_name: client.name, return_window_days: 7 }.merge(attrs))
    end

    def create_request(client, status: :pending, items: [ { resolution: "coupon", price: 100 } ], **attrs)
      request = client.exchange_requests.create!({ shopify_order_id: "1", shopify_order_number: "#1001",
                                                   customer_email: "maria@example.com", customer_name: "Maria",
                                                   status: status, return_mode: "agencia" }.merge(attrs))
      items.each do |item|
        request.exchange_request_items.create!({ product_name: "Vestido", quantity: 1, reason: "nao_gostei", kind: :troca }.merge(item))
      end
      request
    end

    # Pedido normalizado como o de Shopify::FindOrderForExchange.
    def build_order(delivered_days_ago: 2, **attrs)
      {
        id: "999", number: "#1001", email: "maria@example.com", phone: "11999998888", zip: "01310100",
        customer_id: "gid://shopify/Customer/1", created_at: (delivered_days_ago + 3).days.ago, cancelled: false,
        fulfilled_at: (delivered_days_ago + 1).days.ago, delivered_at: delivered_days_ago.days.ago,
        tags: [], channel: "web", gateways: [ "shopify_payments" ], shipping_paid: 20.0,
        items: [
          { line_item_id: "gid://shopify/LineItem/1", product_id: "gid://shopify/Product/10", variant_id: "gid://shopify/ProductVariant/100",
            sku: "VEST-M", product_name: "Vestido", variant_title: "M", quantity: 2, price: 150.0, current_price: 150.0, weight_g: 300,
            product_tags: [ "verao" ], collections: [ { id: "gid://shopify/Collection/5", title: "Verão" } ],
            variants: [ { id: "gid://shopify/ProductVariant/100", title: "M", price: 150.0, available: true },
                        { id: "gid://shopify/ProductVariant/101", title: "G", price: 170.0, available: true } ] },
          { line_item_id: "gid://shopify/LineItem/2", product_id: "gid://shopify/Product/20", variant_id: "gid://shopify/ProductVariant/200",
            sku: "CAM-G", product_name: "Camisa", variant_title: "G", quantity: 1, price: 80.0, current_price: 80.0, weight_g: 200,
            product_tags: [ "final-sale" ], collections: [],
            variants: [ { id: "gid://shopify/ProductVariant/200", title: "G", price: 80.0, available: true } ] }
        ]
      }.merge(attrs)
    end

    def create_user(client: nil, profile_id: Profile::USER, email: "user@example.com")
      User.create!(email: email, password: "senha123", client: client, profile_id: profile_id)
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
