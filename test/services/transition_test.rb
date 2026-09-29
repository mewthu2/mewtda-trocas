require "test_helper"

class TransitionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @client = create_client
    create_config(@client, coupon_validity_days: 15)
  end

  test "aprovar gera cupom com o valor dos itens de troca" do
    request = create_request(@client, items: [ { kind: :troca, price: 100, quantity: 2 }, { kind: :devolucao, price: 50 } ])
    captured = nil

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**kwargs) { captured = kwargs; "RECABC12345" }) do
      assert_enqueued_with(job: SendExchangeEmailJob, args: [ { exchange_request_id: request.id, kind: "approved" } ]) do
        assert Exchange::Transition.new(request).call("approved")
      end
    end

    assert request.reload.approved?
    assert_equal "RECABC12345", request.coupon_code
    assert_equal 200.0, captured[:amount]
    assert_equal 15.days, captured[:expires_in]
  end

  test "aprovar só devolução não gera cupom" do
    request = create_request(@client, items: [ { kind: :devolucao, price: 50 } ])

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**) { raise "não deveria chamar" }) do
      assert Exchange::Transition.new(request).call("approved")
    end
    assert_nil request.reload.coupon_code
  end

  test "não permite pular etapas" do
    request = create_request(@client)

    assert_not Exchange::Transition.new(request).call("completed")
    assert request.reload.pending?
  end
end
