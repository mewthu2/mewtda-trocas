module Exchange
  # Conferência: o produto chegou. Reserva estoque (se configurado para a
  # conferência) e, se a loja só resolve depois de conferir, executa o
  # resultado e conclui a solicitação.
  class Receive
    def initialize(exchange_request, user: nil)
      @exchange_request = exchange_request
      @user = user
    end

    def call
      request = @exchange_request
      request.update!(status: :received, received_at: Time.current)
      Exchange::Notify.call(request, "received", public_message: "Produto recebido e conferido.")
      Exchange::ReserveStock.new(request).call_if("inspection")
      return request unless request.config.resolve_on == "inspection"

      if Exchange::Resolve.new(request, user: @user).call
        request.update!(status: :completed, completed_at: Time.current)
        Exchange::Notify.call(request, "completed", public_message: "Solicitação concluída.")
      end
      request
    end
  end
end
