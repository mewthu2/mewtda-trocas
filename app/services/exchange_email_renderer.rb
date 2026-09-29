# Monta o HTML do e-mail (logo, imagem opcional do template e corpo) a partir
# de app/views/exchange_mailer/email.html.erb.
class ExchangeEmailRenderer
  def initialize(config, kind)
    @config = config
    @kind = kind
  end

  def call(subject:, body:)
    ApplicationController.render(
      template: "exchange_mailer/email",
      layout: false,
      locals: {
        config: @config,
        subject: subject,
        body: body,
        image_url: blob_url(@config.email_image(@kind)),
        logo_url: blob_url(@config.logo)
      }
    )
  end

  private

  def blob_url(attachment)
    return unless attachment.attached?

    Rails.application.routes.url_helpers.rails_blob_url(attachment, host: ENV.fetch("APP_HOST", "localhost:3000"),
                                                                    protocol: Rails.env.production? ? "https" : "http")
  end
end
