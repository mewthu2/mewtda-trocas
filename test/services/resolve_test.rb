require "test_helper"

class ResolveTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @client = create_client
    @config = create_config(@client, coupon_validity_days: 15, lower_price_action: "credit", higher_price_action: "charge")
  end

  test "crédito desconta o frete pago pelo cliente" do
    request = create_request(@client, items: [ { resolution: "store_credit", price: 100 } ],
                                      shipping_payer: "customer", shipping_cost: 20)
    captured = nil

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**kwargs) { captured = kwargs; "RECABC" }) do
      assert Exchange::Resolve.new(request).call
    end

    assert_equal 80.0, captured[:amount]
    assert_equal 15.days, captured[:expires_in]
    assert_equal "RECABC", request.reload.coupon_code
    assert_equal 80.0, request.credit_amount
  end

  test "nova peça mais cara envia fatura do complemento" do
    request = create_request(@client, items: [ { resolution: "other_variant", price: 100, new_variant_id: "gid://v/2",
                                                 new_variant_price: 130, shopify_variant_id: "gid://v/1" } ])
    fake = Object.new
    def fake.draft(**args)
      @args = args
      { "id" => "gid://draft/1", "name" => "#D1" }
    end
    def fake.send_invoice(_id) = "https://loja/fatura"
    def fake.args = @args

    with_stubbed(Shopify::ReplacementOrder, :new, fake) do
      assert Exchange::Resolve.new(request).call
    end

    assert_equal 30.0, fake.args[:charge]
    line = fake.args[:lines].sole
    assert_equal "gid://v/2", line[:variant_id]
    assert_equal 130.0, line[:price].to_f
    assert_equal "https://loja/fatura", request.reload.invoice_url
    assert_equal 30.0, request.price_difference
  end

  test "reembolso de pedido pago com Pix fica pendente para a equipe" do
    request = create_request(@client, items: [ { resolution: "refund", price: 90, reason: "arrependimento" } ],
                                      refund_details: { "gateways" => [ "Pix (manual)" ], "pix_key" => "maria@pix" })

    assert Exchange::Resolve.new(request).call

    refund = request.exchange_refunds.sole
    assert_equal "pix", refund.method
    assert_equal "pending", refund.status
    assert_equal 90.0, refund.amount
    assert_includes refund.notes, "maria@pix"
  end

  test "reembolso no cartão vai pela Shopify" do
    request = create_request(@client, items: [ { resolution: "refund", price: 90, shopify_line_item_id: "gid://li/1" } ],
                                      refund_details: { "gateways" => [ "shopify_payments" ] })
    captured = nil
    result = Shopify::CreateRefund::Result.new(refund_id: "gid://refund/1", amount: 90.0, gateway: "shopify_payments")

    with_stubbed(Shopify::CreateRefund, :call, ->(**kwargs) { captured = kwargs; result }) do
      assert Exchange::Resolve.new(request).call
    end

    assert_equal [ { line_item_id: "gid://li/1", quantity: 1 } ], captured[:items]
    assert_equal "done", request.exchange_refunds.sole.status
  end

  test "falha na Shopify é registrada no histórico sem quebrar" do
    request = create_request(@client, items: [ { resolution: "store_credit", price: 50 } ])

    with_stubbed(Shopify::CreateDiscountCode, :call, nil) do
      assert_not Exchange::Resolve.new(request).call
    end
    assert request.exchange_events.exists?(kind: "error")
  end
end
