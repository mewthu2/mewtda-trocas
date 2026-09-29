module Public
  # Fluxo do cliente final: busca o pedido (número + e-mail), escolhe itens,
  # tipo (troca/devolução) e motivo, e envia a solicitação.
  class ExchangesController < ApplicationController
    skip_before_action :authenticate_user!, :block_affiliates!

    layout "public"

    before_action :set_config
    before_action :require_active_config!

    def new; end

    def lookup
      @order = find_order
      return render_order_not_found unless @order

      prepare_lookup
    end

    def create
      @order = find_order
      return render_order_not_found unless @order

      prepare_lookup
      @customer_name = params[:customer_name]
      selected_items = build_selected_items

      if selected_items.empty?
        flash.now[:alert] = "Selecione ao menos um item e informe o motivo."
        return render :lookup, status: :unprocessable_entity
      end

      exchange_request = ActiveRecord::Base.transaction do
        request = @config.client.exchange_requests.create!(
          shopify_order_id: @order[:id], shopify_order_number: @order[:number],
          customer_email: params[:email], customer_name: params[:customer_name]
        )
        selected_items.each { |item| request.exchange_request_items.create!(item) }
        request
      end

      SendExchangeEmailJob.perform_later(exchange_request_id: exchange_request.id, kind: "requested")
      NotifyExchangeRequestJob.perform_later(exchange_request_id: exchange_request.id)
      render :confirmation
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "Não foi possível enviar: #{e.record.errors.full_messages.to_sentence}"
      render :lookup, status: :unprocessable_entity
    end

    private

    def set_config
      @config = ExchangeConfig.find_by(slug: params[:token])
    end

    def require_active_config!
      render :unavailable, status: :not_found unless @config&.active?
    end

    def prepare_lookup
      @eligibility = Exchange::EligibilityCalculator.new(@config).call(@order)
      @order_number = params[:order_number]
      @email = params[:email]
    end

    def render_order_not_found
      flash.now[:alert] = @throttled ? "Muitas tentativas. Aguarde alguns minutos e tente de novo." :
                                       "Pedido não encontrado. Confira o número do pedido e o e-mail informados."
      render :new, status: :unprocessable_entity
    end

    def find_order
      unless Exchange::LookupThrottle.new.allow?(request.remote_ip)
        @throttled = true
        return nil
      end

      Shopify::FindOrderForExchange.call(client: @config.client, order_number: params[:order_number], email: params[:email])
    end

    def build_selected_items
      return [] if %i[return_and_exchange exchange_only].exclude?(@eligibility)

      allowed_kinds = @eligibility == :return_and_exchange ? %w[troca devolucao] : %w[troca]

      params.fetch(:items, {}).to_unsafe_h.values.filter_map do |raw|
        next unless raw["selected"] == "1"

        source = @order[:items][raw["index"].to_i]
        next unless source
        next unless allowed_kinds.include?(raw["kind"])

        quantity = raw["quantity"].to_i.clamp(1, source[:quantity].clamp(1, nil))
        source.merge(quantity: quantity, kind: raw["kind"], reason: raw["reason"], photo: raw["photo"].presence)
      end
    end
  end
end
