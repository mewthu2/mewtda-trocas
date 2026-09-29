# E-mail ao cliente final em cada etapa, com assunto/corpo/imagem editáveis
# em Configuração > E-mails.
class SendExchangeEmailJob < ApplicationJob
  queue_as :default

  def perform(exchange_request_id:, kind:)
    exchange_request = ExchangeRequest.find(exchange_request_id)
    config = exchange_request.client.exchange_config

    unless config
      Rails.logger.warn "[SendExchangeEmailJob] Client #{exchange_request.client_id} sem ExchangeConfig — pulando envio"
      return
    end

    variables = Exchange::MessageVariables.new(exchange_request)
    subject = variables.interpolate(config.email_subject(kind))
    Ses::SendEmailService.new(exchange_request.client).call(
      to: exchange_request.customer_email,
      subject: subject,
      html_body: ExchangeEmailRenderer.new(config, kind).call(subject: subject, body: variables.interpolate(config.email_body(kind)))
    )
  rescue StandardError => e
    Rails.logger.error "[SendExchangeEmailJob] Falha para exchange_request #{exchange_request_id}: #{e.message}"
  end
end
