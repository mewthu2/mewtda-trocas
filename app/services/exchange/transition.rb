module Exchange
  # Muda o status de uma solicitação a partir das ações da tela de detalhe,
  # respeitando o fluxo pendente -> aprovada/rejeitada -> concluída.
  class Transition
    ALLOWED = {
      "approved" => %w[pending],
      "rejected" => %w[pending],
      "completed" => %w[approved]
    }.freeze

    def initialize(exchange_request)
      @exchange_request = exchange_request
    end

    def call(to)
      return false unless ALLOWED.fetch(to, []).include?(@exchange_request.status)

      if to == "approved"
        Approve.new(@exchange_request).call
      else
        @exchange_request.update!(status: to)
        SendExchangeEmailJob.perform_later(exchange_request_id: @exchange_request.id, kind: to)
      end
      true
    end
  end
end
