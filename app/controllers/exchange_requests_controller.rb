class ExchangeRequestsController < ApplicationController
  PER_PAGE = 25

  before_action :require_client!
  before_action :set_exchange_request, only: %i[show update]

  def index
    base = current_client.exchange_requests
    @counts = base.group(:status).count
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
      if Exchange::Transition.new(@exchange_request).call(params[:status])
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

  private

  def set_exchange_request
    @exchange_request = current_client.exchange_requests.includes(exchange_request_items: { photo_attachment: :blob }).find(params[:id])
  end
end
