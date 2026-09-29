# Registro manual do andamento de reembolsos (Pix, boleto ou falhas da Shopify).
class ExchangeRefundsController < ApplicationController
  before_action :require_client!
  before_action :set_exchange_request

  def create
    refund = @exchange_request.exchange_refunds.new(refund_params)
    if refund.save
      @exchange_request.log!("refund", "Reembolso de #{helpers.brl(refund.amount)} via #{refund.method_label} registrado (#{refund.status_label.downcase}).",
                             user: current_user, public: true)
      Exchange::Notify.call(@exchange_request, "refunded") if refund.status == "done"
      flash[:notice] = "Reembolso registrado."
    else
      flash[:alert] = refund.errors.full_messages.to_sentence
    end
    redirect_to exchange_request_path(@exchange_request), status: :see_other
  end

  def update
    refund = @exchange_request.exchange_refunds.find(params[:id])
    previous = refund.status
    if refund.update(refund_params.slice(:status, :notes))
      if previous != refund.status
        @exchange_request.log!("refund", "Reembolso de #{helpers.brl(refund.amount)} via #{refund.method_label}: #{refund.status_label.downcase}.",
                               user: current_user, public: true)
        Exchange::Notify.call(@exchange_request, "refunded") if refund.status == "done"
      end
      flash[:notice] = "Reembolso atualizado."
    else
      flash[:alert] = refund.errors.full_messages.to_sentence
    end
    redirect_to exchange_request_path(@exchange_request), status: :see_other
  end

  private

  def set_exchange_request
    @exchange_request = current_client.exchange_requests.find(params[:exchange_request_id])
  end

  def refund_params
    params.require(:exchange_refund).permit(:method, :amount, :status, :notes)
  end
end
