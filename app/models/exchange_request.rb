class ExchangeRequest < ApplicationRecord
  STATUS_LABELS = {
    "pending" => "Pendente",
    "approved" => "Aprovada",
    "rejected" => "Rejeitada",
    "received" => "Produto recebido",
    "completed" => "Concluída"
  }.freeze

  RETURN_MODE_LABELS = ExchangeConfig::RETURN_MODES

  REVIEW_REASON_LABELS = {
    "manual_reason" => "Motivo exige análise humana",
    "photo" => "Tem foto para analisar",
    "value" => "Valor acima do limite de aprovação automática",
    "abuse" => "Cliente com muitas solicitações recentes",
    "auto_off" => "Aprovação automática desligada"
  }.freeze

  belongs_to :client
  has_many :exchange_request_items, dependent: :destroy
  has_many :exchange_events, -> { chronological }, dependent: :destroy
  has_many :exchange_refunds, -> { order(:created_at) }, dependent: :destroy

  enum :status, { pending: 0, approved: 1, rejected: 2, completed: 3, received: 4 }

  before_create :generate_public_code

  validates :shopify_order_id, :shopify_order_number, :customer_email, presence: true

  scope :search, lambda { |term|
    next all if term.blank?

    like = "%#{sanitize_sql_like(term.strip)}%"
    where("shopify_order_number ILIKE :q OR customer_email ILIKE :q OR customer_name ILIKE :q OR public_code ILIKE :q", q: like)
  }

  def status_label
    STATUS_LABELS[status]
  end

  def customer_display_name
    customer_name.presence || customer_email
  end

  def config
    client.exchange_config
  end

  def troca_items
    exchange_request_items.select(&:troca?)
  end

  def troca_total
    troca_items.sum(&:subtotal)
  end

  def total
    exchange_request_items.sum(&:subtotal)
  end

  def items_with(*resolutions)
    exchange_request_items.select { |item| resolutions.flatten.include?(item.resolution) }
  end

  def refund_total
    items_with("refund").sum(&:subtotal)
  end

  def credit_items_total
    items_with("store_credit", "other_product").sum(&:subtotal)
  end

  def replacement_items
    items_with("same_variant", "other_variant")
  end

  def customer_pays_shipping?
    shipping_payer == "customer"
  end

  def return_mode_label
    RETURN_MODE_LABELS[return_mode]
  end

  def refunded_amount
    exchange_refunds.select { |r| r.status == "done" }.sum(&:amount)
  end

  def log!(kind, message, user: nil, public: false)
    exchange_events.create!(kind: kind, message: message, user: user, public: public)
  end

  private

  def generate_public_code
    self.public_code ||= loop do
      code = SecureRandom.alphanumeric(8).upcase
      break code unless self.class.exists?(public_code: code)
    end
  end
end
