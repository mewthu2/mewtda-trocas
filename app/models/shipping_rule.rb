# Escolhe o serviço de frete reverso por faixa de CEP e peso. A primeira regra
# (por posição) que casar vence; sem regra, usa o serviço padrão do contrato.
class ShippingRule < ApplicationRecord
  belongs_to :exchange_config

  before_validation :normalize

  validates :service_code, inclusion: { in: CarrierContract::SERVICES.keys }
  validates :zip_start, :zip_end, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_blank: true
  validates :max_weight_g, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }

  def matches?(zip:, weight_g:)
    zip = zip.to_s.gsub(/\D/, "")
    return false if zip_start.present? && zip < zip_start
    return false if zip_end.present? && zip > zip_end
    return false if max_weight_g.present? && weight_g.to_i > max_weight_g

    true
  end

  def description
    parts = []
    parts << "CEP #{zip_start || '00000000'}–#{zip_end || '99999999'}" if zip_start || zip_end
    parts << "até #{max_weight_g} g" if max_weight_g
    parts << "qualquer envio" if parts.empty?
    "#{parts.join(', ')} → #{CarrierContract::SERVICES[service_code]}"
  end

  private

  def normalize
    self.zip_start = zip_start.to_s.gsub(/\D/, "").presence
    self.zip_end = zip_end.to_s.gsub(/\D/, "").presence
  end
end
