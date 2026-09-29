require "test_helper"

class ExchangeReasonTest < ActiveSupport::TestCase
  setup { @config = create_config(create_client) }

  test "configuração nova já vem com os motivos padrão" do
    assert_equal ExchangeReason::DEFAULTS.map { |d| d[:key] }, @config.exchange_reasons.map(&:key)
  end

  test "motivos legais não perdem os mínimos da lei" do
    regret = @config.reason_for("arrependimento")
    regret.update!(resolutions: %w[store_credit], shipping_payer: "customer")
    assert_includes regret.resolutions, "refund"
    assert_equal "store", regret.shipping_payer

    defect = @config.reason_for("defeito")
    defect.update!(requires_photo: false, manual_review: false, resolutions: %w[repair])
    assert defect.requires_photo?
    assert defect.manual_review?
    assert_equal %w[refund repair same_variant], defect.resolutions.sort
  end

  test "exige ao menos um motivo ativo" do
    @config.exchange_reasons.each { |r| r.active = false }
    assert_not @config.valid?
    assert @config.errors.key?(:exchange_reasons)
  end
end
