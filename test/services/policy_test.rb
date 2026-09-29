require "test_helper"

class PolicyTest < ActiveSupport::TestCase
  setup do
    @config = create_config(create_client, return_window_days: 30)
  end

  test "dentro do prazo voluntário mostra todos os motivos" do
    policy = Exchange::Policy.new(@config, build_order(delivered_days_ago: 3))

    assert_equal :ok, policy.status
    keys = policy.item(0).reasons.map { |o| o[:reason].key }
    assert_includes keys, "tamanho"
    assert_includes keys, "arrependimento"
    assert_includes keys, "defeito"
  end

  test "arrependimento some depois de 7 dias, troca voluntária segue o prazo da loja" do
    keys = Exchange::Policy.new(@config, build_order(delivered_days_ago: 10)).item(0).reasons.map { |o| o[:reason].key }

    assert_includes keys, "tamanho"
    assert_not_includes keys, "arrependimento"
  end

  test "depois do prazo voluntário sobra só defeito e erro no pedido" do
    keys = Exchange::Policy.new(@config, build_order(delivered_days_ago: 45)).item(0).reasons.map { |o| o[:reason].key }

    assert_equal %w[produto_errado entrega_incompleta avaria defeito], keys
  end

  test "exceção de prazo por coleção" do
    @config.exchange_rules.create!(rule_type: "window", target: "collection", value: "Verão", days: 60)
    keys = Exchange::Policy.new(@config.reload, build_order(delivered_days_ago: 45)).item(0).reasons.map { |o| o[:reason].key }

    assert_includes keys, "tamanho"
  end

  test "exclusão bloqueia troca voluntária mas mantém arrependimento" do
    @config.exchange_rules.create!(rule_type: "exclude", target: "tag", value: "final-sale")
    keys = Exchange::Policy.new(@config.reload, build_order(delivered_days_ago: 2)).item(1).reasons.map { |o| o[:reason].key }

    assert_not_includes keys, "tamanho"
    assert_includes keys, "arrependimento"
  end

  test "conta a partir do envio quando configurado e desconta itens já pedidos" do
    @config.update!(window_base: "fulfillment")
    policy = Exchange::Policy.new(@config, build_order(delivered_days_ago: 2), already_requested: { "gid://shopify/LineItem/2" => 1 })

    assert_equal 3, policy.days_since
    assert_not policy.item(1).available?
    assert_equal 2, policy.item(0).remaining
  end

  test "pedido não enviado ou cancelado" do
    assert_equal :not_fulfilled, Exchange::Policy.new(@config, build_order(delivered_at: nil, fulfilled_at: nil)).status
    assert_equal :cancelled, Exchange::Policy.new(@config, build_order(cancelled: true)).status
  end
end
