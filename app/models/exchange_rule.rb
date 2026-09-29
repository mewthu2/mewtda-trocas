# Regra de prazo ou de elegibilidade aplicada aos itens do pedido.
#   window  -> prazo diferente (em dias) para o alvo; com período (starts_on/ends_on)
#              vale para pedidos feitos dentro das datas (ex.: Natal).
#   exclude -> o alvo não aceita troca/devolução voluntária.
class ExchangeRule < ApplicationRecord
  RULE_TYPES = { "window" => "Prazo diferente", "exclude" => "Não aceita troca voluntária" }.freeze

  TARGETS = {
    "all" => "Todos os produtos",
    "product" => "Produto (ID)",
    "variant" => "Variante (ID ou SKU)",
    "tag" => "Tag do produto",
    "collection" => "Coleção (ID ou nome)",
    "order_tag" => "Tag do pedido",
    "channel" => "Canal de venda"
  }.freeze

  belongs_to :exchange_config

  validates :rule_type, inclusion: { in: RULE_TYPES.keys }
  validates :target, inclusion: { in: TARGETS.keys }
  validates :value, presence: true, unless: -> { target == "all" }
  validates :days, numericality: { only_integer: true, greater_than: 0 }, if: -> { rule_type == "window" }
  validate :period_order

  scope :windows, -> { where(rule_type: "window") }
  scope :exclusions, -> { where(rule_type: "exclude") }

  # order: pedido normalizado; item: linha normalizada (ver Shopify::FindOrderForExchange).
  def matches?(order, item)
    return false unless in_period?(order[:created_at])

    wanted = value.to_s.strip.downcase
    case target
    when "all" then true
    when "product" then id_match?(item[:product_id], wanted)
    when "variant" then id_match?(item[:variant_id], wanted) || item[:sku].to_s.downcase == wanted
    when "tag" then downcased(item[:product_tags]).include?(wanted)
    when "collection" then Array(item[:collections]).any? { |c| id_match?(c[:id], wanted) || c[:title].to_s.downcase == wanted }
    when "order_tag" then downcased(order[:tags]).include?(wanted)
    when "channel" then order[:channel].to_s.downcase == wanted
    else false
    end
  end

  def description
    base = TARGETS[target]
    base = "#{base}: #{value}" if value.present?
    base += " (#{I18n.l(starts_on)} a #{I18n.l(ends_on)})" if starts_on || ends_on
    base
  end

  private

  def in_period?(ordered_at)
    return true if starts_on.blank? && ends_on.blank?
    return false if ordered_at.blank?

    date = ordered_at.to_date
    (starts_on.nil? || date >= starts_on) && (ends_on.nil? || date <= ends_on)
  end

  # Aceita "123" ou o GID completo da Shopify ("gid://shopify/Product/123").
  def id_match?(gid, wanted)
    gid = gid.to_s.downcase
    gid.present? && (gid == wanted || gid.split("/").last == wanted.split("/").last)
  end

  def downcased(list)
    Array(list).map { |t| t.to_s.strip.downcase }
  end

  def period_order
    return unless starts_on && ends_on && ends_on < starts_on

    errors.add(:ends_on, "deve ser depois do início")
  end
end
