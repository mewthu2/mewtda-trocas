module Ses
  # Cadastro e verificação do domínio de envio da loja na SES (DKIM "Easy DKIM"):
  # cria a identidade, devolve os 3 registros CNAME para o DNS e consulta o status.
  class DomainIdentity
    def initialize(client, ses: nil)
      @client = client
      @ses = ses
    end

    def register!(domain)
      domain = domain.to_s.strip.downcase.delete_prefix("http://").delete_prefix("https://").delete_suffix("/")
      tokens = begin
        ses.create_email_identity(email_identity: domain).dkim_attributes.tokens
      rescue Aws::SESV2::Errors::AlreadyExistsException
        ses.get_email_identity(email_identity: domain).dkim_attributes.tokens
      end
      @client.update!(email_sending_domain: domain, ses_dkim_tokens: tokens, ses_verification_status: "pending",
                      ses_verified_at: nil)
    end

    def refresh!
      return if @client.email_sending_domain.blank?

      identity = ses.get_email_identity(email_identity: @client.email_sending_domain)
      verified = identity.verified_for_sending_status
      @client.update!(
        ses_dkim_tokens: identity.dkim_attributes&.tokens.presence || @client.ses_dkim_tokens,
        ses_verification_status: verified ? "verified" : identity.dkim_attributes&.status.to_s.downcase.presence || "pending",
        ses_verified_at: verified ? (@client.ses_verified_at || Time.current) : nil
      )
    rescue Aws::SESV2::Errors::NotFoundException
      @client.update!(ses_verification_status: "unverified", ses_dkim_tokens: [], ses_verified_at: nil)
    end

    def remove!
      ses.delete_email_identity(email_identity: @client.email_sending_domain) if @client.email_sending_domain.present?
    rescue Aws::SESV2::Errors::NotFoundException
      nil
    ensure
      @client.update!(email_sending_domain: nil, ses_dkim_tokens: [], ses_verification_status: "unverified", ses_verified_at: nil)
    end

    def self.configured?
      ENV["AWS_SES_ACCESS_KEY_ID"].present? && ENV["AWS_SES_SECRET_ACCESS_KEY"].present?
    end

    private

    def ses
      @ses ||= Aws::SESV2::Client.new
    end
  end
end
