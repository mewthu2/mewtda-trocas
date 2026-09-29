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

    def create_request(client, status: :pending, items: [ { kind: :troca, price: 100 } ])
      request = client.exchange_requests.create!(shopify_order_id: "1", shopify_order_number: "#1001",
                                                 customer_email: "maria@example.com", customer_name: "Maria", status: status)
      items.each do |item|
        request.exchange_request_items.create!({ product_name: "Vestido", quantity: 1, reason: "nao_gostei" }.merge(item))
      end
      request
    end

    def create_user(client: nil, profile_id: Profile::USER, email: "user@example.com")
      User.create!(email: email, password: "senha123", client: client, profile_id: profile_id)
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
