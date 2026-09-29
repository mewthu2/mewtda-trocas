class ExchangeConfig < ApplicationRecord
  EMAIL_KINDS = %w[requested approved rejected completed].freeze
  # Etapas extras (sem imagem de destaque) introduzidas com o frete reverso e o reembolso.
  EXTRA_EMAIL_KINDS = %w[label_issued received refunded].freeze
  MESSAGE_KINDS = %w[requested approved rejected label_issued received completed refunded].freeze

  # Prazo legal de arrependimento (CDC art. 49) — não configurável.
  REGRET_WINDOW_DAYS = 7

  WINDOW_BASES = { "delivery" => "Data de entrega", "fulfillment" => "Data de envio" }.freeze
  RETURN_MODES = {
    "agencia" => "Postagem em agência dos Correios",
    "coleta" => "Coleta no endereço do cliente",
    "ponto" => "Ponto de entrega / armário inteligente",
    "loja" => "Entrega em loja física"
  }.freeze
  PRICE_BASES = { "paid" => "Preço pago no pedido", "current" => "Preço atual do produto" }.freeze
  HIGHER_PRICE_ACTIONS = { "charge" => "Cobrar o complemento do cliente", "absorb" => "Loja absorve a diferença" }.freeze
  LOWER_PRICE_ACTIONS = {
    "refund" => "Devolver a diferença (reembolso)",
    "credit" => "Gerar crédito com a diferença",
    "absorb" => "Não devolver a diferença"
  }.freeze
  RESERVE_STOCK_ON = {
    "request" => "Ao abrir a solicitação",
    "approval" => "Após a aprovação",
    "inspection" => "Somente após conferência",
    "never" => "Não reservar"
  }.freeze
  RESOLVE_ON = {
    "approval" => "Na aprovação",
    "inspection" => "Após receber e conferir o produto"
  }.freeze
  CREDIT_TYPES = {
    "coupon" => "Cupom de desconto (uso único)",
    "gift_card" => "Vale-presente Shopify (permite uso parcial)",
    "store_credit" => "Crédito na conta do cliente Shopify (permite uso parcial)"
  }.freeze

  belongs_to :client
  has_many :exchange_reasons, -> { ordered }, dependent: :destroy, inverse_of: :exchange_config
  has_many :exchange_rules, dependent: :destroy, inverse_of: :exchange_config
  has_many :shipping_rules, -> { ordered }, dependent: :destroy, inverse_of: :exchange_config
  has_one :carrier_contract, dependent: :destroy, inverse_of: :exchange_config

  accepts_nested_attributes_for :exchange_reasons, allow_destroy: true
  accepts_nested_attributes_for :exchange_rules, allow_destroy: true,
                                                 reject_if: ->(a) { a[:value].blank? && a[:target] != "all" && a[:id].blank? }
  accepts_nested_attributes_for :shipping_rules, allow_destroy: true
  accepts_nested_attributes_for :carrier_contract, update_only: true

  has_one_attached :logo
  has_one_attached :requested_email_image
  has_one_attached :approved_email_image
  has_one_attached :rejected_email_image
  has_one_attached :completed_email_image

  # Conteúdo inicial dos 4 e-mails — evita que o cliente comece com campos em
  # branco; ele edita livremente depois na aba Templates de e-mail.
  DEFAULT_EMAIL_CONTENT = {
    requested: {
      subject: "Recebemos sua solicitação de troca/devolução",
      body: "Olá {{customer_name}},\n\nRecebemos sua solicitação para o pedido {{order_number}}. " \
            "Nossa equipe vai analisar e te avisamos assim que tiver uma resposta.\n\nObrigado!"
    },
    approved: {
      subject: "Sua solicitação foi aprovada!",
      body: "Olá {{customer_name}},\n\nSua solicitação para o pedido {{order_number}} foi aprovada.\n\n" \
            "Use o cupom {{coupon_code}} na sua próxima compra.\n\nObrigado!"
    },
    rejected: {
      subject: "Sobre sua solicitação de troca/devolução",
      body: "Olá {{customer_name}},\n\nAnalisamos sua solicitação para o pedido {{order_number}} e, " \
            "infelizmente, não foi possível aprová-la dessa vez.\n\nQualquer dúvida, fale com a gente."
    },
    completed: {
      subject: "Sua troca/devolução foi concluída",
      body: "Olá {{customer_name}},\n\nSua solicitação para o pedido {{order_number}} foi concluída.\n\n" \
            "Obrigado por comprar com a gente!"
    },
    label_issued: {
      subject: "Seu código de postagem chegou",
      body: "Olá {{customer_name}},\n\nJá liberamos o envio do produto do pedido {{order_number}}.\n\n" \
            "Código de autorização: {{return_code}}\nVálido até {{return_expires_at}}.\n\n" \
            "Acompanhe tudo em {{tracking_url}}"
    },
    received: {
      subject: "Recebemos seu produto",
      body: "Olá {{customer_name}},\n\nO produto do pedido {{order_number}} chegou e está em conferência. " \
            "Em breve concluímos sua solicitação."
    },
    refunded: {
      subject: "Seu reembolso foi registrado",
      body: "Olá {{customer_name}},\n\nRegistramos o reembolso de {{refund_amount}} referente ao pedido {{order_number}}. " \
            "O prazo para aparecer depende da forma de pagamento."
    }
  }.freeze

  DEFAULT_WHATSAPP_CONTENT = {
    requested: "Olá {{customer_name}}! Recebemos sua solicitação do pedido {{order_number}}. Acompanhe: {{tracking_url}}",
    approved: "Boa notícia, {{customer_name}}! Sua solicitação do pedido {{order_number}} foi aprovada. {{tracking_url}}",
    rejected: "Olá {{customer_name}}, analisamos sua solicitação do pedido {{order_number}} e não foi possível aprovar. {{tracking_url}}",
    label_issued: "{{customer_name}}, seu código de postagem é {{return_code}} (válido até {{return_expires_at}}).",
    received: "{{customer_name}}, recebemos o produto do pedido {{order_number}} e ele está em conferência.",
    completed: "{{customer_name}}, sua solicitação do pedido {{order_number}} foi concluída. Obrigado!",
    refunded: "{{customer_name}}, registramos o reembolso de {{refund_amount}} do pedido {{order_number}}."
  }.freeze

  before_create :generate_slug
  after_initialize :apply_default_email_content, if: :new_record?
  after_initialize :build_default_reasons, if: :new_record?
  before_validation :normalize_return_modes

  validates :accent_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :return_window_days, numericality: { only_integer: true, greater_than: 0 }
  validates :coupon_validity_days, numericality: { only_integer: true, greater_than: 0 }
  validates :defect_window_days, numericality: { only_integer: true, greater_than_or_equal_to: 30 }
  validates :reserve_hours, :abuse_max_requests, :abuse_window_days,
            numericality: { only_integer: true, greater_than: 0 }
  validates :analysis_sla_days, :refund_sla_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :free_shipping_above, :auto_approve_max_value, :customer_shipping_flat_fee,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :company_name, presence: true, if: :active?
  validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :window_base, inclusion: { in: WINDOW_BASES.keys }
  validates :price_basis, inclusion: { in: PRICE_BASES.keys }
  validates :higher_price_action, inclusion: { in: HIGHER_PRICE_ACTIONS.keys }
  validates :lower_price_action, inclusion: { in: LOWER_PRICE_ACTIONS.keys }
  validates :reserve_stock_on, inclusion: { in: RESERVE_STOCK_ON.keys }
  validates :resolve_on, inclusion: { in: RESOLVE_ON.keys }
  validates :credit_type, inclusion: { in: CREDIT_TYPES.keys }
  validate :at_least_one_return_mode
  validate :at_least_one_active_reason

  # Só as 4 etapas originais têm imagem de destaque.
  def email_image(kind)
    public_send(:"#{kind}_email_image") if EMAIL_KINDS.include?(kind.to_s)
  end

  def email_subject(kind)
    self[:"#{kind}_email_subject"]
  end

  def email_body(kind)
    self[:"#{kind}_email_body"].presence || DEFAULT_EMAIL_CONTENT.dig(kind.to_sym, :body)
  end

  def whatsapp_body(kind)
    self[:"#{kind}_whatsapp_body"].presence || DEFAULT_WHATSAPP_CONTENT[kind.to_sym]
  end

  def active_reasons
    exchange_reasons.select(&:active?)
  end

  def reason_for(key)
    exchange_reasons.find { |reason| reason.key == key.to_s }
  end

  def correios_contract
    carrier_contract if carrier_contract&.correios_active?
  end

  def conditions
    {
      "tag" => ("Produto com a etiqueta original" if require_original_tag?),
      "accessories" => ("Todos os acessórios que vieram junto" if require_accessories?),
      "packaging" => ("Na embalagem original" if require_packaging?)
    }.compact
  end

  def support_whatsapp_url
    digits = support_whatsapp.to_s.gsub(/\D/, "")
    return if digits.blank?

    "https://wa.me/#{digits.start_with?('55') ? digits : "55#{digits}"}"
  end

  def partial_credit?
    credit_type != "coupon"
  end

  private

  def apply_default_email_content
    DEFAULT_EMAIL_CONTENT.each do |kind, content|
      next unless has_attribute?(:"#{kind}_email_subject")

      self[:"#{kind}_email_subject"] ||= content[:subject]
      self[:"#{kind}_email_body"] ||= content[:body]
    end
    DEFAULT_WHATSAPP_CONTENT.each do |kind, body|
      self[:"#{kind}_whatsapp_body"] ||= body if has_attribute?(:"#{kind}_whatsapp_body")
    end
  end

  def build_default_reasons
    return if exchange_reasons.any?

    ExchangeReason::DEFAULTS.each_with_index { |attrs, i| exchange_reasons.build(attrs.merge(position: i)) }
  end

  def normalize_return_modes
    self.return_modes = Array(return_modes).compact_blank.uniq & RETURN_MODES.keys
  end

  def at_least_one_return_mode
    errors.add(:return_modes, "escolha ao menos uma forma de envio") if return_modes.blank?
    return unless return_modes.include?("loja") && store_drop_off_addresses.blank?

    errors.add(:store_drop_off_addresses, "informe os endereços das lojas físicas")
  end

  def at_least_one_active_reason
    return if exchange_reasons.reject(&:marked_for_destruction?).any?(&:active?)

    errors.add(:exchange_reasons, "mantenha ao menos um motivo ativo")
  end

  # Slug legível a partir do nome do cliente (ex.: "Loja Teste" -> "loja-teste"),
  # mesmo padrão do painel — links públicos já divulgados continuam valendo.
  def generate_slug
    return if slug.present?

    base = client.name.to_s.parameterize
    self.slug = ExchangeConfig.exists?(slug: base) ? "#{base}-#{client_id}" : base
  end
end
