module Ses
  class SendEmailService
    def initialize(client, ses: nil)
      @client = client
      @ses = ses
    end

    # Só envia se o domínio da loja estiver verificado na SES (Configuração >
    # E-mails, neste app).
    def call(to:, subject:, html_body:)
      return false unless @client.ses_domain_verified?

      ses.send_email(
        from_email_address: @client.email_from_address,
        reply_to_addresses: [ @client.email_reply_to.presence ].compact,
        destination: { to_addresses: [ to ] },
        content: {
          simple: {
            subject: { data: subject },
            body: { html: { data: html_body } }
          }
        }
      )
      true
    end

    private

    def ses
      @ses ||= Aws::SESV2::Client.new
    end
  end
end
