require "test_helper"

class ExchangeRequestItemTest < ActiveSupport::TestCase
  setup { @request = create_request(create_client, items: []) }

  test "tipo vem do resultado escolhido" do
    refund = @request.exchange_request_items.create!(product_name: "Tênis", quantity: 1, price: 10, reason: "arrependimento", resolution: "refund")
    swap = @request.exchange_request_items.create!(product_name: "Tênis", quantity: 1, price: 10, reason: "tamanho", resolution: "other_variant")

    assert refund.devolucao?
    assert swap.troca?
    assert_equal "Reembolso", refund.resolution_label
  end

  test "diferença de preço usa o preço pago ou o atual" do
    item = @request.exchange_request_items.build(product_name: "Tênis", quantity: 2, price: 100, current_price: 90,
                                                 reason: "tamanho", resolution: "other_variant", new_variant_price: 120)

    assert_equal 40.0, item.price_difference("paid")
    assert_equal 60.0, item.price_difference("current")
  end

  test "rejeita resultado desconhecido" do
    item = @request.exchange_request_items.build(product_name: "Tênis", quantity: 1, price: 10, reason: "x", resolution: "magica")

    assert_not item.valid?
  end
end
