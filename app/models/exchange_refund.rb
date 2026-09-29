# Reembolso de uma solicitação. Cartão é estornado pela Shopify; Pix e boleto
# costumam ser pagos fora dela, então a equipe registra o andamento aqui.
class ExchangeRefund < ApplicationRecord
  METHODS = { "card" => "Cartão", "pix" => "Pix", "boleto" => "Boleto", "other" => "Outro" }.freeze
  STATUSES = { "pending" => "Pendente", "processing" => "Em processamento", "done" => "Concluído", "failed" => "Falhou" }.freeze

  belongs_to :exchange_request

  validates :method, inclusion: { in: METHODS.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :amount, numericality: { greater_than: 0 }

  def method_label
    METHODS[method]
  end

  def status_label
    STATUSES[status]
  end
end
