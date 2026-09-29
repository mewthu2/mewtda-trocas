module Exchange
  # Dispara a mensagem da etapa nos canais ligados pela loja e registra no
  # histórico público.
  module Notify
    module_function

    def call(request, kind, public_message: nil)
      config = request.config
      return unless config

      SendExchangeEmailJob.perform_later(exchange_request_id: request.id, kind: kind) if config.email_enabled?
      if config.whatsapp_enabled? && request.customer_phone.present?
        SendExchangeWhatsappJob.perform_later(exchange_request_id: request.id, kind: kind)
      end
      request.log!(kind, public_message, public: true) if public_message
    end
  end
end
