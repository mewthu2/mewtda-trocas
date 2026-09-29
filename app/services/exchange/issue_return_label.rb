module Exchange
  # Libera o envio do produto de volta: com contrato Correios ativo, gera a
  # pré-postagem reversa (autorização de postagem ou coleta); sem contrato,
  # a equipe informa os códigos manualmente.
  class IssueReturnLabel
    Result = Struct.new(:ok, :message, keyword_init: true)

    def initialize(request, user: nil)
      @request = request
      @config = request.config
      @user = user
    end

    def call
      return Result.new(ok: true, message: "Entrega em loja física — não precisa de código.") if @request.return_mode == "loja"

      contract = @config.correios_contract
      return Result.new(ok: false, message: "Sem contrato dos Correios ativo — informe o código manualmente.") unless contract

      data = Correios::Client.new(contract).create_reverse_posting(
        request: @request, service: @request.return_service.presence || contract.default_service,
        weight_g: total_weight(contract), pickup: @request.return_mode == "coleta"
      )
      record!(data[:authorization_code], data[:tracking_code], data[:expires_at])
      Result.new(ok: true, message: "Código de postagem gerado: #{data[:authorization_code]}")
    rescue Correios::Client::Error, StandardError => e
      @request.log!("error", "Falha ao gerar postagem nos Correios: #{e.message}", user: @user)
      Result.new(ok: false, message: e.message)
    end

    def record_manual!(authorization_code:, tracking_code:, expires_at:)
      record!(authorization_code.presence, tracking_code.presence, expires_at.presence && Date.parse(expires_at.to_s))
    end

    private

    def record!(authorization_code, tracking_code, expires_at)
      @request.update!(return_authorization_code: authorization_code, return_tracking_code: tracking_code,
                       return_expires_at: expires_at)
      Exchange::Notify.call(@request, "label_issued",
                            public_message: "Envio liberado. Código de postagem: #{authorization_code || tracking_code}.")
    end

    def total_weight(contract)
      weights = @request.exchange_request_items.map { |item| item.weight_g.to_i * item.quantity }
      [ weights.sum, contract.package_weight_g ].max
    end
  end
end
