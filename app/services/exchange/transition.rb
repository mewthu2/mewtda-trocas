module Exchange
  # Muda o status a partir das ações da tela de detalhe, respeitando o fluxo
  # pendente -> aprovada/rejeitada -> produto recebido -> concluída.
  class Transition
    ALLOWED = {
      "approved" => %w[pending],
      "rejected" => %w[pending],
      "received" => %w[approved],
      "completed" => %w[approved received]
    }.freeze

    def initialize(exchange_request, user: nil)
      @exchange_request = exchange_request
      @user = user
    end

    def call(to, rejection_reason: nil)
      return false unless ALLOWED.fetch(to, []).include?(@exchange_request.status)

      case to
      when "approved" then Approve.new(@exchange_request, user: @user).call
      when "received" then Receive.new(@exchange_request, user: @user).call
      when "rejected"
        @exchange_request.update!(status: :rejected, rejection_reason: rejection_reason.presence)
        release_reservation
        message = [ "Solicitação não aprovada.", rejection_reason.presence ].compact.join(" ")
        Exchange::Notify.call(@exchange_request, "rejected", public_message: message)
      when "completed"
        @exchange_request.update!(status: :completed, completed_at: Time.current)
        Exchange::Notify.call(@exchange_request, "completed", public_message: "Solicitação concluída.")
      end
      true
    end

    private

    def release_reservation
      return if @exchange_request.replacement_draft_order_id.blank?

      @exchange_request.log!("stock_released", "Reserva de estoque não será usada (rascunho #{@exchange_request.replacement_draft_order_id}).",
                             user: @user)
    end
  end
end
