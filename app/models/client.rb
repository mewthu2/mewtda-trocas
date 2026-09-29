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

  EMAIL_DOMAIN_STATUSES = {
    "unverified" => "Sem domínio próprio",
    "pending" => "Aguardando configuração",
    "verified" => "Verificado"
  }.freeze

  def email_domain_verified?
    email_domain_status == "verified" && email_sending_domain.present?
  end

  # Remetente dos e-mails: o domínio próprio da loja quando verificado no
  # Mailer To Go; senão, o domínio padrão da Mewtda (MAILERTOGO_DOMAIN).
  def email_from_domain
    email_domain_verified? ? email_sending_domain : ENV["MAILERTOGO_DOMAIN"].presence
  end

  def email_from_address
    domain = email_from_domain
    return if domain.blank?

    address = "#{email_from_local.presence || 'trocas'}@#{domain}"
    name = email_from_name.presence || exchange_config&.company_name.presence || self.name
    name.present? ? "#{name.delete('"<>')} <#{address}>" : address
  end

  def email_reply_to_address
    email_reply_to.presence || exchange_config&.support_email.presence
  end

  def zapi_configured?
    zapi_instance_id.present? && zapi_instance_token.present? && zapi_client_token.present?
  end
end
