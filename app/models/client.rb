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
  validates :email_from_local, format: { with: /\A[a-z0-9._+-]+\z/i }, allow_blank: true
  validates :email_reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def shopify_configured?
    shopify_shop_url.present? && shopify_access_token.present?
  end

  def ses_domain_verified?
    ses_verification_status == "verified" && email_sending_domain.present?
  end

  def email_from_address
    address = "#{email_from_local.presence || 'naoresponda'}@#{email_sending_domain}"
    name = email_from_name.presence || exchange_config&.company_name.presence || self.name
    name.present? ? "#{name.delete('"<>')} <#{address}>" : address
  end

  # Registros CNAME do Easy DKIM que a loja precisa criar no DNS.
  def dkim_records
    Array(ses_dkim_tokens).map do |token|
      { name: "#{token}._domainkey.#{email_sending_domain}", value: "#{token}.dkim.amazonses.com" }
    end
  end

  def zapi_configured?
    zapi_instance_id.present? && zapi_instance_token.present? && zapi_client_token.present?
  end
end
