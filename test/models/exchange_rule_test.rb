require "test_helper"

class ExchangeRuleTest < ActiveSupport::TestCase
  setup do
    @order = build_order
    @item = @order[:items].first
  end

  test "casa por tag, coleção, variante/SKU, produto e canal" do
    assert rule("tag", "VERAO").matches?(@order, @item)
    assert rule("collection", "verão").matches?(@order, @item)
    assert rule("collection", "5").matches?(@order, @item)
    assert rule("variant", "vest-m").matches?(@order, @item)
    assert rule("product", "10").matches?(@order, @item)
    assert rule("channel", "web").matches?(@order, @item)
    assert_not rule("tag", "inverno").matches?(@order, @item)
  end

  test "período vale pela data do pedido" do
    inside = rule("all", nil, starts_on: 10.days.ago.to_date, ends_on: Date.current)
    outside = rule("all", nil, starts_on: 1.day.from_now.to_date)

    assert inside.matches?(@order, @item)
    assert_not outside.matches?(@order, @item)
  end

  private

  def rule(target, value, **attrs)
    ExchangeRule.new(rule_type: "window", target: target, value: value, days: 30, **attrs)
  end
end
