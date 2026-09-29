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
      refund_method, bank = refund_choice(items)

      ActiveRecord::Base.transaction do
        @request = @config.client.exchange_requests.create!(
          shopify_order_id: @order[:id], shopify_order_number: @order[:number], shopify_customer_id: @order[:customer_id],
          customer_email: @params[:email], customer_name: @params[:customer_name],
          customer_phone: @params[:customer_phone].presence || @order[:phone], customer_zip: zip,
          delivered_at: @policy.base_date, return_mode: return_mode, refund_method: refund_method,
          refund_details: { "gateways" => @order[:gateways], "order_shipping" => @order[:shipping_paid] }.merge(bank).compact
        )
        items.each { |attrs| @request.exchange_request_items.create!(attrs.except(:reason_record)) }
        apply_shipping(reasons, zip, items)
      end

      @request.log!("requested", "Solicitação recebida.", public: true)
      Exchange::Notify.call(@request, "requested")
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
          quantity: raw["quantity"].to_i.clamp(1, options.remaining), price: item[:price],
          weight_g: item[:weight_g], shopify_line_item_id: item[:line_item_id], shopify_product_id: item[:product_id],
          shopify_variant_id: item[:variant_id], reason: reason.key, reason_label: reason.label, resolution: resolution,
          answers: answers_for(reason, raw), photo: raw["photo"].presence, reason_record: reason
        }
        attrs[:conditions_confirmed] = conditions_confirmed?(reason, raw)

        if reason.requires_photo? && attrs[:photo].blank?
          raise Invalid, "Envie uma foto de #{item[:product_name]} para esse motivo."
        end
        attrs
      end
    end

    BANK_FIELDS = {
      "pix" => %w[pix_key account_holder],
      "transferencia" => %w[bank_name bank_agency bank_account account_holder holder_document]
    }.freeze

    # Com devolução do dinheiro, o cliente escolhe como receber; Pix e
    # transferência exigem os dados bancários.
    def refund_choice(items)
      return [ nil, {} ] unless items.any? { |i| i[:resolution] == "refund" }

      method = @params[:refund_method].presence_in(@config.refund_methods)
      raise Invalid, "Escolha como você quer receber o dinheiro de volta." unless method

      fields = BANK_FIELDS.fetch(method, [])
      bank = fields.to_h { |field| [ field, @params[field].to_s.strip.first(120).presence ] }
      raise Invalid, "Preencha os dados para receber por #{ExchangeRefund::METHODS[method]}." if bank.values.any?(&:nil?)

      [ method, bank ]
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
