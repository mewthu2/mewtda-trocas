require "test_helper"

class ShippingQuoteTest < ActiveSupport::TestCase
  setup do
    @config = create_config(create_client, free_shipping_first_attempt: false, customer_shipping_flat_fee: 25)
    @order = build_order
  end

  test "motivo legal: loja paga" do
    assert_equal "store", quote(%w[defeito]).payer
  end

  test "motivo voluntário do cliente: cobra a taxa" do
    result = quote(%w[cor])
    assert_equal "customer", result.payer
    assert_equal 25.0, result.cost
  end

  test "primeira troca grátis e faixa de valor" do
    @config.update!(free_shipping_first_attempt: true)
    assert_equal "store", quote(%w[cor]).payer
    assert_equal "customer", quote(%w[cor], previous: 1).payer

    @config.update!(free_shipping_above: 300)
    assert_equal "store", quote(%w[cor], previous: 1).payer
  end

  test "serviço escolhido pela faixa de CEP" do
    @config.shipping_rules.create!(zip_start: "01000000", zip_end: "05999999", service_code: "03247")
    assert_equal "03247", quote(%w[cor]).service
  end

  private

  def quote(keys, previous: 0)
    @config.reload
    reasons = keys.map { |k| @config.reason_for(k) }
    Exchange::ShippingQuote.new(@config, order: @order, reasons: reasons, weight_g: 300, zip: "01310100",
                                         previous_requests: previous).call
  end
end
