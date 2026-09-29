class Zapi::Client
  include HTTParty

  base_uri "https://api.z-api.io"

  # Usa a instância Zapi do cliente; sem ela (ou com client nil), cai na
  # instância global da Mewtda definida no ENV.
  def initialize(client)
    @instance_id = client&.zapi_instance_id.presence || ENV["ZAPI_INSTANCE_ID"]
    @instance_token = client&.zapi_instance_token.presence || ENV["ZAPI_INSTANCE_TOKEN"]
    @client_token = client&.zapi_client_token.presence || ENV["ZAPI_CLIENT_TOKEN"]
  end

  def send_text(phone:, message:)
    unless @instance_id.present? && @instance_token.present? && @client_token.present?
      Rails.logger.error("[ZAPI] credenciais não configuradas")
      return nil
    end

    response = self.class.post(
      "/instances/#{@instance_id}/token/#{@instance_token}/send-text",
      headers: { "Content-Type" => "application/json", "Client-Token" => @client_token },
      body: { phone:, message: }.to_json
    )
    response.parsed_response
  rescue StandardError => e
    Rails.logger.error("[ZAPI] erro ao enviar mensagem: #{e.message}")
    nil
  end
end
