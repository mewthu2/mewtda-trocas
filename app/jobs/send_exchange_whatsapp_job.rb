# WhatsApp ao cliente final em cada etapa, pela instância Z-API da loja (ou a
# global da Mewtda).
class SendExchangeWhatsappJob < ApplicationJob
  queue_as :default

  def perform(exchange_request_id:, kind:)
    request = ExchangeRequest.find(exchange_request_id)
    client = request.client
    return unless client.whatsapp_available? && request.customer_phone.present?

    message = Exchange::MessageVariables.new(request).interpolate(request.config.whatsapp_body(kind))
    Zapi::Client.new(client).send_text(phone: format_phone(request.customer_phone), message: message)
  rescue StandardError => e
    Rails.logger.error "[SendExchangeWhatsappJob] Falha para exchange_request #{exchange_request_id}: #{e.message}"
  end

  private

  def format_phone(phone)
    digits = phone.to_s.gsub(/\D/, "")
    digits.start_with?("55") ? digits : "55#{digits}"
  end
end
