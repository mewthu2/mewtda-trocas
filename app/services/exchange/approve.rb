module Exchange
  # Aprova a solicitação: libera a postagem reversa e, se a loja resolve na
  # aprovação, já gera o cupom e registra a devolução do dinheiro.
  class Approve
    def initialize(exchange_request, user: nil, auto: false)
      @exchange_request = exchange_request
      @user = user
      @auto = auto
    end

    def call
      request = @exchange_request
      request.update!(status: :approved, approved_at: Time.current, auto_approved: @auto)
      request.log!("approved", @auto ? "Aprovada automaticamente." : "Solicitação aprovada.", user: @user, public: true)
      Exchange::Notify.call(request, "approved")

      Exchange::IssueReturnLabel.new(request, user: @user).call if request.return_authorization_code.blank?
      Exchange::Resolve.new(request, user: @user).call if request.config.resolve_on == "approval"
      request
    end
  end
end
