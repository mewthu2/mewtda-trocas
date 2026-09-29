module Ses
  class SendEmailService
    def initialize(client, ses: nil)
      @client = client
      @ses = ses
    end

    # Só envia se o domínio do cliente estiver verificado na SES (configurado
    # no painel, em Config. de E-mail).
    def call(to:, subject:, html_body:)
      return false unless @client.ses_domain_verified?

      ses.send_email(
        from_email_address: "naoresponda@#{@client.email_sending_domain}",
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
