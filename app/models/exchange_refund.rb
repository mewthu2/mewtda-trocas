# Devolução do dinheiro, sempre feita pela equipe fora da plataforma: estorno
# no meio de pagamento original, Pix ou transferência. O comprovante é anexado
# aqui e fica visível para o cliente na página de acompanhamento.
class ExchangeRefund < ApplicationRecord
  METHODS = {
    "estorno" => "Estorno no meio de pagamento da compra",
    "pix" => "Pix",
    "transferencia" => "Transferência bancária"
  }.freeze
  STATUSES = { "pending" => "Pendente", "processing" => "Em processamento", "done" => "Concluído", "failed" => "Falhou" }.freeze

  belongs_to :exchange_request
  has_one_attached :receipt

  validates :method, inclusion: { in: METHODS.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :amount, numericality: { greater_than: 0 }
  validate :receipt_is_image_or_pdf

  def method_label
    METHODS[method]
  end

  def status_label
    STATUSES[status]
  end

  def receipt_expected?
    %w[pix transferencia].include?(method)
  end

  private

  def receipt_is_image_or_pdf
    return unless receipt.attached?
    return if receipt.content_type.to_s.start_with?("image/") || receipt.content_type == "application/pdf"

    errors.add(:receipt, "deve ser imagem ou PDF")
  end
end
