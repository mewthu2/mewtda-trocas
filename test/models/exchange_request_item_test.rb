require "test_helper"

class ExchangeRequestItemTest < ActiveSupport::TestCase
  setup { @request = create_request(create_client, items: []) }

  test "exige foto quando o motivo é defeito" do
    item = @request.exchange_request_items.build(product_name: "Tênis", quantity: 1, price: 10, kind: :troca, reason: "defeito")

    assert_not item.valid?
    assert item.errors.key?(:photo)

    item.photo.attach(io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")
    assert item.valid?
  end

  test "rejeita motivo fora da lista" do
    item = @request.exchange_request_items.build(product_name: "Tênis", quantity: 1, price: 10, kind: :troca, reason: "qualquer")

    assert_not item.valid?
  end
end
