# Histórico da solicitação. Eventos públicos aparecem na página de
# acompanhamento do cliente; os demais só na área logada.
class ExchangeEvent < ApplicationRecord
  belongs_to :exchange_request
  belongs_to :user, optional: true

  validates :kind, :message, presence: true

  scope :chronological, -> { order(:created_at, :id) }
  scope :visible_to_customer, -> { where(public: true) }
end
