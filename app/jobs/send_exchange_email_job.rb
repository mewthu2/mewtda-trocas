# E-mail ao cliente final em cada etapa (SMTP do Mailer To Go), com assunto,
# corpo e imagem editáveis em Configuração > Comunicação.
class SendExchangeEmailJob < ApplicationJob
  queue_as :default

  def perform(exchange_request_id:, kind:)
    exchange_request = ExchangeRequest.find(exchange_request_id)
    client = exchange_request.client
    config = client.exchange_config

    unless config && client.email_from_address
      Rails.logger.warn "[SendExchangeEmailJob] Client #{client.id} sem configuração ou domínio de envio — pulando envio"
      return
    end

    variables = Exchange::MessageVariables.new(exchange_request)
    subject = variables.interpolate(config.email_subject(kind))
    html = ExchangeEmailRenderer.new(config, kind).call(subject: subject, body: variables.interpolate(config.email_body(kind)))

    ExchangeMailer.notification(
      to: exchange_request.customer_email, from: client.email_from_address, reply_to: client.email_reply_to_address,
      subject: subject, html: html
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error "[SendExchangeEmailJob] Falha para exchange_request #{exchange_request_id}: #{e.message}"
  end
end
