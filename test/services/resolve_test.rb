require "test_helper"

class ResolveTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @client = create_client
    @config = create_config(@client, coupon_validity_days: 15, coupon_combines_with_discounts: true)
  end

  test "cupom no valor dos itens, descontando o frete pago pelo cliente" do
    request = create_request(@client, items: [ { resolution: "coupon", price: 100 } ],
                                      shipping_payer: "customer", shipping_cost: 20, shopify_customer_id: "gid://shopify/Customer/9")
    captured = nil

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**kwargs) { captured = kwargs; "RECABC" }) do
      assert Exchange::Resolve.new(request).call
    end

    assert_equal 80.0, captured[:amount]
    assert_equal 15.days, captured[:expires_in]
    assert captured[:combines]
    assert_equal "gid://shopify/Customer/9", captured[:customer_id]
    assert_equal "RECABC", request.reload.coupon_code
    assert_equal 80.0, request.credit_amount
  end

  test "devolução do dinheiro fica pendente com a forma escolhida pelo cliente" do
    request = create_request(@client, items: [ { resolution: "refund", price: 90, reason: "arrependimento" } ],
                                      refund_method: "pix", refund_details: { "pix_key" => "maria@pix" })

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**) { raise "não deveria gerar cupom" }) do
      assert Exchange::Resolve.new(request).call
    end

    refund = request.exchange_refunds.sole
    assert_equal "pix", refund.method
    assert_equal "pending", refund.status
    assert_equal 90.0, refund.amount
  end

  test "cupom e devolução juntos; frete maior que o cupom sai da devolução" do
    request = create_request(@client, items: [ { resolution: "coupon", price: 10 }, { resolution: "refund", price: 100 } ],
                                      refund_method: "estorno", shipping_payer: "customer", shipping_cost: 25)

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**) { "RECX" }) do
      assert Exchange::Resolve.new(request).call
    end

    assert_nil request.reload.coupon_code
    assert_equal 85.0, request.exchange_refunds.sole.amount
  end

  test "não duplica cupom nem devolução se rodar de novo" do
    request = create_request(@client, items: [ { resolution: "coupon", price: 50 }, { resolution: "refund", price: 30 } ],
                                      refund_method: "estorno")
    calls = 0

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**) { calls += 1; "RECONE" }) do
      2.times { Exchange::Resolve.new(request.reload).call }
    end

    assert_equal 1, calls
    assert_equal 1, request.exchange_refunds.count
  end

  test "arrependimento do pedido inteiro devolve também o frete da compra" do
    request = create_request(@client, items: [ { resolution: "refund", price: 90, reason: "arrependimento" } ],
                                      refund_method: "estorno", refund_details: { "all_items" => true, "order_shipping" => 15.0 })

    assert Exchange::Resolve.new(request).call
    assert_equal 105.0, request.exchange_refunds.sole.amount
  end

  test "frete da compra só entra em outros motivos se a loja optar" do
    details = { "all_items" => true, "order_shipping" => 15.0 }
    request = create_request(@client, items: [ { resolution: "refund", price: 90, reason: "defeito" } ],
                                      refund_method: "estorno", refund_details: details)
    Exchange::Resolve.new(request).call
    assert_equal 90.0, request.exchange_refunds.sole.amount

    @config.update!(refund_original_shipping: true)
    other = create_request(@client, items: [ { resolution: "refund", price: 90, reason: "defeito" } ],
                                    refund_method: "estorno", refund_details: details)
    Exchange::Resolve.new(other.reload).call
    assert_equal 105.0, other.exchange_refunds.sole.amount
  end

  test "falha na Shopify é registrada no histórico sem quebrar" do
    request = create_request(@client, items: [ { resolution: "coupon", price: 50 } ])

    with_stubbed(Shopify::CreateDiscountCode, :call, nil) do
      assert_not Exchange::Resolve.new(request).call
    end
    assert request.exchange_events.exists?(kind: "error")
  end
end
