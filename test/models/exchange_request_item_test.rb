require "test_helper"

class ExchangeRequestItemTest < ActiveSupport::TestCase
  setup { @request = create_request(create_client, items: []) }

  test "tipo vem do resultado escolhido" do
    refund = @request.exchange_request_items.create!(product_name: "Tênis", quantity: 1, price: 10, reason: "arrependimento", resolution: "refund")
    swap = @request.exchange_request_items.create!(product_name: "Tênis", quantity: 1, price: 10, reason: "tamanho", resolution: "coupon")

    assert refund.devolucao?
    assert swap.troca?
    assert_equal "Devolução do dinheiro", refund.resolution_label
  end

  test "rejeita resultado desconhecido" do
    item = @request.exchange_request_items.build(product_name: "Tênis", quantity: 1, price: 10, reason: "x", resolution: "other_variant")

    assert_not item.valid?
  end
end
