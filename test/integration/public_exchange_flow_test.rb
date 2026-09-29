require "test_helper"

class PublicExchangeFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    @client = create_client
    @config = create_config(@client, return_window_days: 30, support_email: "sac@loja.com")
    @order = build_order
  end

  test "página inativa mostra indisponível" do
    @config.update!(active: false)
    get public_exchange_path(@config.slug)
    assert_response :not_found
  end

  test "link antigo redireciona e rodapé mostra o atendimento" do
    get "/crm/troca/#{@config.slug}"
    assert_redirected_to "/troca/#{@config.slug}"

    get public_exchange_path(@config.slug)
    assert_select ".public__support", /sac@loja.com/
  end

  test "pedido não encontrado" do
    with_stubbed(Shopify::FindOrderForExchange, :call, nil) do
      post public_exchange_lookup_path(@config.slug), params: { order_number: "1", email: "x@y.com" }
    end
    assert_response :unprocessable_entity
    assert_match "Pedido não encontrado", response.body
  end

  test "fluxo completo: cupom por tamanho e devolução por Pix no defeito" do
    with_stubbed(Shopify::FindOrderForExchange, :call, @order) do
      post public_exchange_lookup_path(@config.slug), params: { order_number: "1001", email: "maria@example.com" }
      assert_response :success
      assert_select "fieldset.pick-item", 2

      assert_difference -> { ExchangeRequestItem.count }, 2 do
        post public_exchange_path(@config.slug), params: {
          order_number: "1001", email: "maria@example.com", customer_name: "Maria", customer_phone: "11988887777",
          return_mode: "agencia", refund_method: "pix", pix_key: "maria@pix.com", account_holder: "Maria Silva",
          items: {
            "0" => { index: "0", selected: "1", reason: "tamanho", resolution: "coupon", quantity: "1" },
            "1" => { index: "1", selected: "1", reason: "defeito", resolution: "refund",
                     answers: { "0" => "Costura abriu", "1" => "No primeiro uso" },
                     photo: fixture_file_upload("photo.png", "image/png") }
          }
        }
      end
    end

    assert_response :success
    request = ExchangeRequest.last
    assert request.pending?
    assert_includes request.review_reasons, "manual_reason"
    assert_equal "11988887777", request.customer_phone
    assert_equal "store", request.shipping_payer

    assert_equal "pix", request.refund_method
    assert_equal "maria@pix.com", request.bank_details["pix_key"]
    assert request.exchange_request_items.find_by(sku: "VEST-M").troca?
    defect = request.exchange_request_items.find_by(sku: "CAM-G")
    assert defect.photo.attached?
    assert defect.devolucao?
    assert_equal "Costura abriu", defect.answers["Descreva o defeito"]

    assert_enqueued_with(job: SendExchangeEmailJob, args: [ { exchange_request_id: request.id, kind: "requested" } ])

    get public_exchange_tracking_path(@config.slug, request.public_code)
    assert_response :success
    assert_select "h1", "Pendente"
  end

  test "caso simples com aprovação automática" do
    @config.update!(auto_approve: true)

    with_stubbed(Shopify::FindOrderForExchange, :call, @order) do
      with_stubbed(Shopify::CreateDiscountCode, :call, ->(**) { "RECAUTO" }) do
        post public_exchange_path(@config.slug), params: {
          order_number: "1001", email: "maria@example.com", customer_name: "Maria",
          items: { "0" => { index: "0", selected: "1", reason: "tamanho", resolution: "coupon", quantity: "1" } }
        }
      end
    end

    request = ExchangeRequest.last
    assert request.approved?
    assert request.auto_approved?
    assert_equal "RECAUTO", request.coupon_code
    assert_select "h1", "Solicitação aprovada!"
  end

  test "fora do prazo voluntário não aceita troca por tamanho" do
    with_stubbed(Shopify::FindOrderForExchange, :call, build_order(delivered_days_ago: 45)) do
      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria",
        items: { "0" => { index: "0", selected: "1", reason: "tamanho", resolution: "coupon" } }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 0, ExchangeRequest.count
  end

  test "defeito sem foto e condições não confirmadas não são aceitos" do
    @config.update!(require_original_tag: true)

    with_stubbed(Shopify::FindOrderForExchange, :call, @order) do
      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria",
        items: { "0" => { index: "0", selected: "1", reason: "defeito", resolution: "refund",
                          answers: { "0" => "a", "1" => "b" } } }
      }
      assert_response :unprocessable_entity
      assert_match "foto", response.body

      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria",
        items: { "0" => { index: "0", selected: "1", reason: "tamanho", resolution: "coupon" } }
      }
      assert_response :unprocessable_entity
      assert_match "Confirme as condições", response.body
    end

    assert_equal 0, ExchangeRequest.count
  end

  test "devolução sem dados bancários é recusada" do
    with_stubbed(Shopify::FindOrderForExchange, :call, @order) do
      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria", refund_method: "transferencia", bank_name: "Itaú",
        items: { "0" => { index: "0", selected: "1", reason: "arrependimento", resolution: "refund" } }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Preencha os dados", response.body
    assert_equal 0, ExchangeRequest.count
  end

  test "resultado não permitido para o motivo é recusado" do
    with_stubbed(Shopify::FindOrderForExchange, :call, @order) do
      post public_exchange_path(@config.slug), params: {
        order_number: "1001", email: "maria@example.com", customer_name: "Maria",
        items: { "0" => { index: "0", selected: "1", reason: "nao_gostei", resolution: "refund" } }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 0, ExchangeRequest.count
  end
end
