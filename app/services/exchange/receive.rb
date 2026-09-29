module Exchange
  # Conferência: o produto chegou. Se a loja só resolve depois de conferir,
  # gera o cupom e registra a devolução do dinheiro agora.
  class Receive
    def initialize(exchange_request, user: nil)
      @exchange_request = exchange_request
      @user = user
    end

    def call
      request = @exchange_request
      request.update!(status: :received, received_at: Time.current)
      Exchange::Notify.call(request, "received", public_message: "Produto recebido e conferido.")
      return request unless request.config.resolve_on == "inspection"

      # Só com cupom (sem devolução de dinheiro pendente) já dá para concluir.
      if Exchange::Resolve.new(request, user: @user).call && request.exchange_refunds.reload.none?
        request.update!(status: :completed, completed_at: Time.current)
        Exchange::Notify.call(request, "completed", public_message: "Solicitação concluída.")
      end
      request
    end
  end
end
