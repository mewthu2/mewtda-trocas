require "test_helper"

class PublicExchangeFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ORDER = {
    id: "999", number: "#1001", email: "maria@example.com", cancelled: false, fulfilled_at: 2.days.ago,
    items: [
      { sku: "VEST-M", product_name: "Vestido", variant_title: "M", quantity: 2, price: 150.0 },
      { sku: "CAM-G", product_name: "Camisa", variant_title: "G", quantity: 1, price: 80.0 }
    ]
  }.freeze

  setup do
    Rails.cache.clear
    @client = create_client
    @config = create_config(@client)
  end

  test "página inativa mostra indisponível" do
    @config.update!(active: false)
    get public_exchange_path(@config.slug)
    assert_response :not_found
  end

  test "link antigo do painel redireciona" do
    get "/crm/troca/#{@config.slug}"
    assert_redirected_to "/troca/#{@config.slug}"
  end

  test "pedido não encontrado" do
    with_stubbed(Shopify::FindOrderForExchange, :call, nil) do
      post public_exchange_lookup_path(@config.slug), params: { order_number: "1", email: "x@y.com" }
    end
    assert_response :unprocessable_entity
    assert_match "Pedido não encontrado", response.body
  end

  test "fluxo completo de solicitação" do
    get public_exchange_path(@config.slug)
    assert_response :success

    with_stubbed(Shopify::FindOrderForExchange, :call, ORDER) do
      post public_exchange_lookup_path(@config.slug), params: { order_number: "1001", email: "maria@example.com" }
      assert_response :success
      assert_select "fieldset.pick-item", 2

      assert_difference -> { ExchangeRequestItem.count }, 2 do
        post public_exchange_path(@config.slug), params: {
          order_number: "1001", email: "maria@example.com", customer_name: "Maria",
          items: {
            "0" => { index: "0", selected: "1", kind: "troca", reason: "tamanho_nao_serviu", quantity: "1" },
            "1" => { index: "1", selected: "1", kind: "devolucao", reason: "defeito",
                     photo: fixture_file_upload("photo.png", "image/png") }
          }
        }
      end
    end

    assert_response :success
    request = ExchangeRequest.last
    assert_equal "#1001", request.shopify_order_number
    assert_equal 150.0, request.troca_total
    assert request.exchange_request_items.find_by(sku: "CAM-G").photo.attached?
    assert_enqueued_with(job: SendExchangeEmailJob, args: [ { exchange_request_id: request.id, kind: "requested" } ])
    assert_enqueued_with(job: NotifyExchangeRequestJob, args: [ { exchange_request_id: request.id } ])
  end

  test "fora do prazo não aceita devolução" do
    order = ORDER.merge(fulfilled_at: 30.days.ago)

    with_stubbed(Shopify::FindOrderForExchange, :call, order) do
      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria",
        items: { "0" => { index: "0", selected: "1", kind: "devolucao", reason: "nao_gostei" } }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 0, ExchangeRequest.count
  end

  test "defeito sem foto não é aceito" do
    with_stubbed(Shopify::FindOrderForExchange, :call, ORDER) do
      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria",
        items: { "0" => { index: "0", selected: "1", kind: "troca", reason: "defeito" } }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 0, ExchangeRequest.count
  end
end
