# Motivo de troca/devolução configurável por loja. A categoria define o que é
# obrigatório por lei (CDC) e não pode ser desligado pelo lojista:
#   - regret (arrependimento, art. 49): 7 dias da entrega, devolução do dinheiro sempre
#     disponível e frete por conta da loja;
#   - defect (vício, art. 18) e logistics (erro da loja): foto e análise humana,
#     frete por conta da loja, devolução do dinheiro sempre disponível;
#   - voluntary: segue só a política da loja.
class ExchangeReason < ApplicationRecord
  CATEGORIES = {
    "voluntary" => "Troca voluntária (política da loja)",
    "regret" => "Direito de arrependimento (CDC art. 49)",
    "defect" => "Vício do produto (CDC art. 18)",
    "logistics" => "Erro no pedido ou na entrega"
  }.freeze

  # Aprovada a solicitação, o cliente recebe um cupom (vale-troca para comprar
  # outra peça), o dinheiro de volta (feito pela equipe) ou o reparo do produto.
  RESOLUTIONS = {
    "coupon" => "Cupom para comprar outra peça",
    "refund" => "Devolução do dinheiro",
    "repair" => "Reparo do produto"
  }.freeze

  MONEY_RESOLUTIONS = %w[refund].freeze

  REQUIRED_RESOLUTIONS = {
    "regret" => %w[refund],
    "defect" => %w[refund],
    "logistics" => %w[refund]
  }.freeze

  SHIPPING_PAYERS = { "store" => "Loja", "customer" => "Cliente" }.freeze

  DEFAULTS = [
    { key: "tamanho", label: "Tamanho não serviu", category: "voluntary", resolutions: %w[coupon], shipping_payer: "store" },
    { key: "cor", label: "Quero outra cor", category: "voluntary", resolutions: %w[coupon], shipping_payer: "customer" },
    { key: "nao_gostei", label: "Não gostei do produto", category: "voluntary", resolutions: %w[coupon], shipping_payer: "customer" },
    { key: "arrependimento", label: "Desisti da compra (arrependimento)", category: "regret", resolutions: %w[refund coupon] },
    { key: "produto_errado", label: "Recebi um produto diferente do pedido", category: "logistics",
      resolutions: %w[coupon refund], requires_photo: true },
    { key: "entrega_incompleta", label: "Faltou item na entrega", category: "logistics",
      resolutions: %w[coupon refund], questions: "Qual item ou acessório faltou?" },
    { key: "avaria", label: "Produto chegou avariado", category: "defect",
      resolutions: %w[coupon refund], requires_photo: true, questions: "A embalagem chegou danificada?" },
    { key: "defeito", label: "Produto com defeito", category: "defect",
      resolutions: %w[coupon repair refund], requires_photo: true,
      questions: "Descreva o defeito\nQuando o defeito apareceu?" }
  ].freeze

  belongs_to :exchange_config

  before_validation :apply_legal_minimums
  before_validation :normalize

  validates :label, presence: true
  validates :key, presence: true, format: { with: /\A[a-z0-9_]+\z/ },
                  uniqueness: { scope: :exchange_config_id }
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :shipping_payer, inclusion: { in: SHIPPING_PAYERS.keys }
  validate :resolutions_known

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def self.build_defaults
    DEFAULTS.each_with_index.map { |attrs, i| new(attrs.merge(position: i)) }
  end

  def legal?
    category != "voluntary"
  end

  def voluntary?
    category == "voluntary"
  end

  def regret?
    category == "regret"
  end

  def question_list
    questions.to_s.lines.map(&:strip).compact_blank
  end

  private

  def apply_legal_minimums
    return unless legal?

    self.shipping_payer = "store"
    self.resolutions = (Array(resolutions) + REQUIRED_RESOLUTIONS.fetch(category, [])).uniq
    self.requires_photo = true if category == "defect"
    self.manual_review = true if %w[defect logistics].include?(category)
  end

  def normalize
    self.key = (key.presence || label.to_s).parameterize(separator: "_").first(40) if key.blank? || new_record?
    self.resolutions = Array(resolutions).compact_blank.uniq & RESOLUTIONS.keys
  end

  def resolutions_known
    errors.add(:resolutions, "precisa ter ao menos uma opção") if resolutions.blank?
  end
end
