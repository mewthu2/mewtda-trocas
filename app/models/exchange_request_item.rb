class ExchangeRequestItem < ApplicationRecord
  belongs_to :exchange_request
  has_one_attached :photo

  # "troca" = sai um produto novo (ou reparo); "devolucao" = volta dinheiro/crédito.
  enum :kind, { troca: 0, devolucao: 1 }

  KIND_LABELS = { "troca" => "Troca", "devolucao" => "Devolução" }.freeze

  # Motivos de solicitações antigas (antes dos motivos configuráveis).
  LEGACY_REASONS = {
    "tamanho_nao_serviu" => "Tamanho não serviu",
    "outro" => "Outro motivo"
  }.freeze

  before_validation :derive_kind

  validates :product_name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :reason, presence: true
  validates :resolution, inclusion: { in: ExchangeReason::RESOLUTIONS.keys }, allow_nil: true

  def reason_label
    self[:reason_label].presence || LEGACY_REASONS[reason] || reason.to_s.humanize
  end

  def kind_label
    KIND_LABELS[kind]
  end

  def resolution_label
    ExchangeReason::RESOLUTIONS[resolution] || kind_label
  end

  def subtotal
    price.to_f * quantity.to_i
  end

  # Preço usado na comparação com a nova peça (pago ou atual, conforme a loja).
  def comparison_price(basis)
    basis == "current" && current_price.present? ? current_price.to_f : price.to_f
  end

  def price_difference(basis)
    return 0 unless resolution == "other_variant" && new_variant_price.present?

    ((new_variant_price.to_f - comparison_price(basis)) * quantity.to_i).round(2)
  end

  def replacement_variant_id
    resolution == "other_variant" ? new_variant_id : shopify_variant_id
  end

  private

  def derive_kind
    return if resolution.blank?

    self.kind = ExchangeReason::MONEY_RESOLUTIONS.include?(resolution) ? :devolucao : :troca
  end
end
