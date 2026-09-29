module Public
  # Fluxo do cliente final: busca o pedido (número + e-mail), escolhe itens,
  # motivo, resultado e forma de envio, e acompanha a solicitação depois.
  class ExchangesController < ApplicationController
    skip_before_action :authenticate_user!, :block_affiliates!

    layout "public"

    before_action :set_config
    before_action :require_active_config!, except: :tracking

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
      creator = Exchange::CreateRequest.new(config: @config, order: @order, policy: @policy, params: request_params)
      @exchange_request = creator.call
      render :confirmation
    rescue Exchange::CreateRequest::Invalid => e
      flash.now[:alert] = e.message
      render :lookup, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "Não foi possível enviar: #{e.record.errors.full_messages.to_sentence}"
      render :lookup, status: :unprocessable_entity
    end

    # Página de acompanhamento (link nos e-mails/WhatsApp).
    def tracking
      return render(:unavailable, status: :not_found) unless @config&.tracking_page_enabled?

      @exchange_request = @config.client.exchange_requests.includes(:exchange_request_items, :exchange_events)
                                 .find_by(public_code: params[:code].to_s.upcase)
      render :unavailable, status: :not_found unless @exchange_request
    end

    private

    def set_config
      @config = ExchangeConfig.includes(:exchange_reasons, :exchange_rules, :shipping_rules, :carrier_contract)
                              .find_by(slug: params[:token])
    end

    def require_active_config!
      render :unavailable, status: :not_found unless @config&.active?
    end

    def prepare_lookup
      @policy = Exchange::Policy.new(@config, @order, already_requested: already_requested)
      @order_number = params[:order_number]
      @email = params[:email]
    end

    def already_requested
      @config.client.exchange_requests.where(shopify_order_id: @order[:id]).where.not(status: :rejected)
             .joins(:exchange_request_items).group("exchange_request_items.shopify_line_item_id")
             .sum("exchange_request_items.quantity")
    end

    def request_params
      params.permit(:email, :customer_name, :customer_phone, :customer_zip, :return_mode, :refund_method,
                    :pix_key, :bank_name, :bank_agency, :bank_account, :account_holder, :holder_document,
                    items: {}).to_h.with_indifferent_access.tap do |p|
        p[:items] = params.fetch(:items, {}).to_unsafe_h.transform_values do |raw|
          raw.to_h.merge("photo" => raw["photo"])
        end
      end
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
  end
end
