require "test_helper"

class EligibilityCalculatorTest < ActiveSupport::TestCase
  setup { @calculator = Exchange::EligibilityCalculator.new(ExchangeConfig.new(return_window_days: 7)) }

  test "classifica pedido conforme envio e prazo" do
    assert_equal :cancelled, @calculator.call(cancelled: true, fulfilled_at: 1.day.ago)
    assert_equal :not_fulfilled, @calculator.call(cancelled: false, fulfilled_at: nil)
    assert_equal :return_and_exchange, @calculator.call(cancelled: false, fulfilled_at: 7.days.ago)
    assert_equal :exchange_only, @calculator.call(cancelled: false, fulfilled_at: 8.days.ago)
  end
end
