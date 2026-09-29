# Loja cliente da Mewtda. Mesma estrutura da tabela do mewtda-painel, mas em
# banco próprio.
class Client < ApplicationRecord
  # Colunas criptografadas pelo painel (ActiveRecord::Encryption com as chaves
  # dele). Este app não precisa delas, então nem carrega.
  self.ignored_columns += %w[meta_access_token google_ads_refresh_token shopify_api_secret]

  has_many :users, dependent: :nullify
  has_one :exchange_config, dependent: :destroy
  has_many :exchange_requests, dependent: :destroy

  validates :name, presence: true

  def shopify_configured?
    shopify_shop_url.present? && shopify_access_token.present?
  end

  def ses_domain_verified?
    ses_verification_status == "verified"
  end
end
