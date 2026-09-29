class ExchangeRequest < ApplicationRecord
  STATUS_LABELS = {
    "pending" => "Pendente",
    "approved" => "Aprovada",
    "rejected" => "Rejeitada",
    "completed" => "Concluída"
  }.freeze

  belongs_to :client
  has_many :exchange_request_items, dependent: :destroy

  enum :status, { pending: 0, approved: 1, rejected: 2, completed: 3 }

  validates :shopify_order_id, :shopify_order_number, :customer_email, presence: true

  scope :search, lambda { |term|
    next all if term.blank?

    like = "%#{sanitize_sql_like(term.strip)}%"
    where("shopify_order_number ILIKE :q OR customer_email ILIKE :q OR customer_name ILIKE :q", q: like)
  }

  def status_label
    STATUS_LABELS[status]
  end

  def customer_display_name
    customer_name.presence || customer_email
  end

  def troca_items
    exchange_request_items.select(&:troca?)
  end

  def troca_total
    troca_items.sum { |item| item.price.to_f * item.quantity.to_i }
  end

  def total
    exchange_request_items.sum { |item| item.price.to_f * item.quantity.to_i }
  end
end
