require "test_helper"

class ReviewDecisionTest < ActiveSupport::TestCase
  setup do
    @client = create_client
    @config = create_config(@client, auto_approve: true, auto_approve_max_value: 500, abuse_max_requests: 2)
  end

  test "caso simples é aprovado sozinho" do
    request = create_request(@client)
    assert Exchange::ReviewDecision.new(request, [ @config.reason_for("tamanho") ]).auto_approve?
  end

  test "defeito, valor alto e abuso vão para análise" do
    request = create_request(@client, items: [ { resolution: "refund", price: 600 } ])
    2.times { create_request(@client) }

    reasons = Exchange::ReviewDecision.new(request, [ @config.reason_for("defeito") ]).reasons
    assert_equal %w[manual_reason value abuse], reasons
  end
end
