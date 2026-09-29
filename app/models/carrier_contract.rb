# Contrato de frete reverso da loja. Hoje: Correios (API com usuário do Meu
# Correios + código de acesso, cartão de postagem e código administrativo) ou
# "manual", quando a loja só envia instruções de postagem ao cliente.
class CarrierContract < ApplicationRecord
  CARRIERS = { "correios" => "Correios (contrato)", "manual" => "Instruções manuais / outra transportadora" }.freeze

  # Serviços de logística reversa dos Correios.
  SERVICES = {
    "03301" => "PAC Reverso",
    "03247" => "SEDEX Reverso",
    "04677" => "e-Sedex Reverso"
  }.freeze

  STATES = %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO].freeze

  belongs_to :exchange_config

  encrypts :access_code

  before_validation :normalize

  validates :carrier, inclusion: { in: CARRIERS.keys }
  validates :default_service, inclusion: { in: SERVICES.keys }
  validates :package_weight_g, :package_length_cm, :package_width_cm, :package_height_cm, :authorization_days,
            numericality: { only_integer: true, greater_than: 0 }
  validates :username, :access_code, :posting_card, :administrative_code, :contract_number,
            :sender_name, :sender_zip, :sender_street, :sender_number, :sender_district, :sender_city, :sender_state,
            presence: true, if: :correios_active?
  validates :sender_zip, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_blank: true
  validates :sender_state, inclusion: { in: STATES }, allow_blank: true

  def correios?
    carrier == "correios"
  end

  def correios_active?
    active? && correios?
  end

  def masked_access_code
    access_code.present? ? "••••#{access_code.last(4)}" : nil
  end

  def service_label(code = default_service)
    SERVICES[code] || code
  end

  private

  def normalize
    self.sender_zip = sender_zip.to_s.gsub(/\D/, "").presence
    self.sender_document = sender_document.to_s.gsub(/\D/, "").presence
    self.posting_card = posting_card.to_s.strip.presence
    self.sender_state = sender_state.to_s.upcase.presence
  end
end
