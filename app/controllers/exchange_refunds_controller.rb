# Devoluções de dinheiro feitas pela equipe (estorno, Pix, transferência):
# andamento e comprovante. Com o produto recebido e todas as devoluções
# concluídas, a solicitação é concluída automaticamente.
class ExchangeRefundsController < ApplicationController
  before_action :require_client!
  before_action :set_exchange_request

  def create
    refund = @exchange_request.exchange_refunds.new(refund_params)
    if refund.save
      @exchange_request.log!("refund", "Devolução de #{helpers.brl(refund.amount)} (#{refund.method_label}) registrada: #{refund.status_label.downcase}.",
                             user: current_user, public: true)
      Exchange::Notify.call(@exchange_request, "refunded") if refund.status == "done"
      complete_if_settled
      flash[:notice] = "Devolução registrada."
    else
      flash[:alert] = refund.errors.full_messages.to_sentence
    end
    redirect_to exchange_request_path(@exchange_request), status: :see_other
  end

  def update
    refund = @exchange_request.exchange_refunds.find(params[:id])
    previous = refund.status
    if refund.update(refund_params.slice(:status, :notes, :receipt))
      if previous != refund.status
        @exchange_request.log!("refund", "Devolução de #{helpers.brl(refund.amount)} (#{refund.method_label}): #{refund.status_label.downcase}.",
                               user: current_user, public: true)
        Exchange::Notify.call(@exchange_request, "refunded") if refund.status == "done"
      end
      complete_if_settled
      flash[:notice] = "Devolução atualizada."
    else
      flash[:alert] = refund.errors.full_messages.to_sentence
    end
    redirect_to exchange_request_path(@exchange_request), status: :see_other
  end

  private

  def complete_if_settled
    return unless @exchange_request.received?
    return unless @exchange_request.exchange_refunds.reload.all? { |r| r.status == "done" }

    Exchange::Transition.new(@exchange_request, user: current_user).call("completed")
  end

  def set_exchange_request
    @exchange_request = current_client.exchange_requests.find(params[:exchange_request_id])
  end

  def refund_params
    params.require(:exchange_refund).permit(:method, :amount, :status, :notes, :receipt)
  end
end
