module Exchange
  # Registra a solicitação vinda da página pública: valida cada item contra a
  # política (motivo, resultado, condições, foto), calcula o frete reverso,
  # decide entre aprovação automática e análise humana e avisa o cliente.
  class CreateRequest
    class Invalid < StandardError; end

    attr_reader :request

    def initialize(config:, order:, policy:, params:)
      @config = config
      @order = order
      @policy = policy
      @params = params
    end

    def call
      items = build_items
      raise Invalid, "Selecione ao menos um item e informe o motivo." if items.empty?

      reasons = items.map { |i| i[:reason_record] }.uniq
      return_mode = @params[:return_mode].presence_in(@config.return_modes) || @config.return_modes.first
      zip = @params[:customer_zip].to_s.gsub(/\D/, "").presence || @order[:zip]

      ActiveRecord::Base.transaction do
        @request = @config.client.exchange_requests.create!(
          shopify_order_id: @order[:id], shopify_order_number: @order[:number], shopify_customer_id: @order[:customer_id],
          customer_email: @params[:email], customer_name: @params[:customer_name],
          customer_phone: @params[:customer_phone].presence || @order[:phone], customer_zip: zip,
          delivered_at: @policy.base_date, return_mode: return_mode,
          refund_details: {
            "gateways" => @order[:gateways], "order_shipping" => @order[:shipping_paid],
            "pix_key" => @params[:pix_key].presence,
            "all_items" => all_items?(items)
          }.compact
        )
        items.each { |attrs| @request.exchange_request_items.create!(attrs.except(:reason_record)) }
        apply_shipping(reasons, zip, items)
      end

      @request.log!("requested", "Solicitação recebida.", public: true)
      Exchange::Notify.call(@request, "requested")
      Exchange::ReserveStock.new(@request).call_if("request")
      decide(reasons)
      @request
    end

    private

    def build_items
      @params.fetch(:items, {}).values.filter_map do |raw|
        next unless raw["selected"] == "1"

        options = @policy.item(raw["index"])
        next unless options&.available?

        option = options.reason(raw["reason"])
        raise Invalid, "Escolha um motivo válido para #{options.item[:product_name]}." unless option

        reason = option[:reason]
        resolution = raw["resolution"].presence_in(option[:resolutions])
        raise Invalid, "Escolha o que você prefere para #{options.item[:product_name]}." unless resolution

        item = options.item
        attrs = {
          sku: item[:sku], product_name: item[:product_name], variant_title: item[:variant_title],
          quantity: raw["quantity"].to_i.clamp(1, options.remaining), price: item[:price], current_price: item[:current_price],
          weight_g: item[:weight_g], shopify_line_item_id: item[:line_item_id], shopify_product_id: item[:product_id],
          shopify_variant_id: item[:variant_id], reason: reason.key, reason_label: reason.label, resolution: resolution,
          answers: answers_for(reason, raw), photo: raw["photo"].presence, reason_record: reason
        }
        attrs.merge!(new_variant(item, raw["new_variant_id"])) if resolution == "other_variant"
        attrs[:conditions_confirmed] = conditions_confirmed?(reason, raw)

        if reason.requires_photo? && attrs[:photo].blank?
          raise Invalid, "Envie uma foto de #{item[:product_name]} para esse motivo."
        end
        attrs
      end
    end

    def new_variant(item, variant_id)
      variant = @policy.other_variants(item).find { |v| v[:id] == variant_id }
      raise Invalid, "Escolha o novo tamanho/cor de #{item[:product_name]}." unless variant

      { new_variant_id: variant[:id], new_variant_title: variant[:title], new_variant_price: variant[:price] }
    end

    def answers_for(reason, raw)
      given = raw["answers"].respond_to?(:to_h) ? raw["answers"].to_h : {}
      reason.question_list.each_with_index.to_h do |question, i|
        answer = given[i.to_s].to_s.strip
        raise Invalid, "Responda: #{question}" if answer.blank?

        [ question, answer.first(1000) ]
      end
    end

    def conditions_confirmed?(reason, raw)
      return true unless reason.voluntary? && @config.conditions.any?
      return true if raw["conditions"] == "1"

      raise Invalid, "Confirme as condições do produto para a troca."
    end

    def all_items?(items)
      requested = items.sum { |i| i[:quantity] }
      requested >= @order[:items].sum { |i| i[:quantity].to_i }
    end

    def apply_shipping(reasons, zip, items)
      return if @request.return_mode == "loja"

      contract = @config.correios_contract
      quote = Exchange::ShippingQuote.new(
        @config, order: @order, reasons: reasons, zip: zip,
                 weight_g: [ items.sum { |i| i[:weight_g].to_i * i[:quantity] }, contract&.package_weight_g.to_i ].max,
                 previous_requests: @config.client.exchange_requests.where(shopify_order_id: @order[:id]).where.not(id: @request.id).count,
                 correios: contract && Correios::Client.new(contract)
      ).call
      @request.update!(shipping_payer: quote.payer, shipping_cost: quote.cost, return_service: quote.service)
    end

    def decide(reasons)
      decision = Exchange::ReviewDecision.new(@request, reasons)
      if decision.auto_approve?
        Exchange::Approve.new(@request, auto: true).call
      else
        @request.update!(flagged_for_review: decision.reasons.intersect?(%w[abuse value]), review_reasons: decision.reasons)
      end
    end
  end
end
