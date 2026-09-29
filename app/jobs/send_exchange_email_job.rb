# E-mail ao cliente final em cada etapa (requested/approved/rejected/completed),
# com assunto/corpo/imagem editáveis em Templates de e-mail.
class SendExchangeEmailJob < ApplicationJob
  queue_as :default

  def perform(exchange_request_id:, kind:)
    exchange_request = ExchangeRequest.find(exchange_request_id)
    config = exchange_request.client.exchange_config

    unless config
      Rails.logger.warn "[SendExchangeEmailJob] Client #{exchange_request.client_id} sem ExchangeConfig — pulando envio"
      return
    end

    subject = interpolate(config.email_subject(kind), exchange_request)
    Ses::SendEmailService.new(exchange_request.client).call(
      to: exchange_request.customer_email,
      subject: subject,
      html_body: ExchangeEmailRenderer.new(config, kind).call(
        subject: subject, body: interpolate(config.email_body(kind), exchange_request)
      )
    )
  rescue StandardError => e
    Rails.logger.error "[SendExchangeEmailJob] Falha para exchange_request #{exchange_request_id}: #{e.message}"
  end

  private

  def interpolate(text, exchange_request)
    text.to_s
        .gsub("{{customer_name}}", exchange_request.customer_name.to_s)
        .gsub("{{order_number}}", exchange_request.shopify_order_number.to_s)
        .gsub("{{coupon_code}}", exchange_request.coupon_code.to_s)
  end
end
