class ExchangeRequestsController < ApplicationController
  PER_PAGE = 25

  before_action :require_client!
  before_action :set_exchange_request, only: %i[show update return_label]

  def index
    base = current_client.exchange_requests
    @counts = base.group(:status).count
    @review_count = base.pending.where(flagged_for_review: true).count
    @status_filter = params[:status].presence_in(ExchangeRequest.statuses.keys)
    @query = params[:q].to_s.strip

    scope = base.includes(:exchange_request_items).search(@query).order(created_at: :desc)
    scope = scope.where(status: @status_filter) if @status_filter
    @page = [ params[:page].to_i, 1 ].max
    @total_count = scope.count
    @exchange_requests = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @total_pages = (@total_count / PER_PAGE.to_f).ceil
  end

  def show; end

  def update
    if params[:status].present?
      if Exchange::Transition.new(@exchange_request, user: current_user).call(params[:status], rejection_reason: params[:rejection_reason])
        flash[:notice] = "Solicitação marcada como #{@exchange_request.status_label.downcase}."
      else
        flash[:alert] = "Essa mudança de status não é permitida."
      end
    end

    if params.key?(:internal_notes)
      @exchange_request.update!(internal_notes: params[:internal_notes])
      flash[:notice] ||= "Nota interna salva."
    end

    redirect_to exchange_request_path(@exchange_request), status: :see_other
  end

  # Gera a postagem reversa nos Correios ou grava os códigos informados à mão.
  def return_label
    service = Exchange::IssueReturnLabel.new(@exchange_request, user: current_user)
    if params[:manual] == "1"
      service.record_manual!(authorization_code: params[:authorization_code], tracking_code: params[:tracking_code],
                             expires_at: params[:expires_at])
      flash[:notice] = "Códigos de postagem salvos e enviados ao cliente."
    else
      result = service.call
      flash[result.ok ? :notice : :alert] = result.message
    end
    redirect_to exchange_request_path(@exchange_request), status: :see_other
  end

  private

  def set_exchange_request
    @exchange_request = current_client.exchange_requests
                                      .includes(:exchange_events, :exchange_refunds, exchange_request_items: { photo_attachment: :blob })
                                      .find(params[:id])
  end
end
