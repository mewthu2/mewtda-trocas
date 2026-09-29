require "test_helper"

class TransitionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @client = create_client
    @config = create_config(@client, coupon_validity_days: 15)
  end

  test "aprovar gera crédito dos itens de crédito e avisa o cliente" do
    request = create_request(@client, items: [ { resolution: "other_product", price: 100, quantity: 2 }, { resolution: "store_credit", price: 50 } ])
    captured = nil

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**kwargs) { captured = kwargs; "RECABC12345" }) do
      assert_enqueued_with(job: SendExchangeEmailJob, args: [ { exchange_request_id: request.id, kind: "approved" } ]) do
        assert Exchange::Transition.new(request).call("approved")
      end
    end

    assert request.reload.approved?
    assert request.approved_at
    assert_equal "RECABC12345", request.coupon_code
    assert_equal 250.0, captured[:amount]
  end

  test "resolver só após conferência: aprovar não gera crédito, receber gera e conclui" do
    @config.update!(resolve_on: "inspection")
    request = create_request(@client)

    with_stubbed(Shopify::CreateDiscountCode, :call, ->(**) { "RECINSP" }) do
      assert Exchange::Transition.new(request).call("approved")
      assert_nil request.reload.coupon_code

      assert Exchange::Transition.new(request).call("received")
    end

    assert request.reload.completed?
    assert_equal "RECINSP", request.coupon_code
  end

  test "rejeitar guarda o motivo" do
    request = create_request(@client)

    assert Exchange::Transition.new(request).call("rejected", rejection_reason: "Produto usado")
    assert_equal "Produto usado", request.reload.rejection_reason
    assert request.exchange_events.exists?(kind: "rejected", public: true)
  end

  test "não permite pular etapas" do
    request = create_request(@client)

    assert_not Exchange::Transition.new(request).call("completed")
    assert_not Exchange::Transition.new(request).call("received")
    assert request.reload.pending?
  end
end
