module Exchange
  # Executa o resultado de cada item depois da aprovação (ou da conferência,
  # conforme a loja):
  #   - crédito (crédito na loja / outro produto / diferença a favor do cliente):
  #     cupom, vale-presente ou crédito na conta Shopify;
  #   - reembolso: estorno pela Shopify na forma original; Pix/boleto ficam
  #     registrados para a equipe acompanhar;
  #   - troca por produto: pedido de reposição (com fatura se houver complemento);
  #   - reparo: fica com a equipe (registrado no histórico).
  # Frete pago pelo cliente é descontado do crédito/reembolso ou somado ao complemento.
  class Resolve
    MANUAL_GATEWAYS = /pix|boleto|manual|dep[oó]sito|transfer/i

    def self.replacement_lines(request)
      request.replacement_items.map do |item|
        { variant_id: item.replacement_variant_id, quantity: item.quantity,
          price: item.new_variant_price.presence || item.comparison_price(request.config.price_basis) }
      end
    end

    def initialize(request, user: nil)
      @request = request
      @config = request.config
      @client = request.client
      @user = user
      @errors = []
    end

    def call
      totals = compute_totals
      @request.update!(price_difference: totals[:difference])

      issue_credit(totals[:credit]) if totals[:credit].positive?
      issue_refunds(totals) if totals[:refund].positive? || totals[:refund_extra].positive?
      issue_replacement(totals[:charge]) if @request.replacement_items.any?
      if @request.items_with("repair").any?
        log("Reparo: a equipe deve consertar e reenviar o produto ao cliente.")
      end
      @errors.empty?
    end

    def errors
      @errors
    end

    private

    def compute_totals
      basis = @config.price_basis
      difference = @request.exchange_request_items.sum { |item| item.price_difference(basis) }.round(2)
      higher = [ difference, 0 ].max
      lower = [ -difference, 0 ].max

      credit = @request.credit_items_total
      refund = @request.refund_total
      refund_extra = 0
      charge = @config.higher_price_action == "charge" ? higher : 0
      case @config.lower_price_action
      when "credit" then credit += lower
      when "refund" then refund_extra += lower
      end

      shipping = @request.customer_pays_shipping? ? @request.shipping_cost.to_f : 0
      shipping_left = shipping
      [ :credit, :refund ].each do |key|
        value = key == :credit ? credit : refund
        cut = [ value, shipping_left ].min
        shipping_left -= cut
        key == :credit ? credit -= cut : refund -= cut
      end
      charge += shipping_left

      { difference: difference, credit: credit.round(2), refund: refund.round(2), refund_extra: refund_extra.round(2),
        charge: charge.round(2), shipping_deducted: (shipping - shipping_left).round(2) }
    end

    def issue_credit(amount)
      validity = @config.coupon_validity_days.days
      customer_id = @config.credit_link_customer? ? @request.shopify_customer_id : nil
      code = case @config.credit_type
      when "gift_card"
        Shopify::CreateGiftCard.call(client: @client, amount: amount, expires_in: validity, customer_id: customer_id,
                                     note: "Troca #{@request.public_code}")
      when "store_credit"
        Shopify::CreditStoreCredit.call(client: @client, customer_id: @request.shopify_customer_id, amount: amount,
                                        expires_in: validity)
        "CRÉDITO NA CONTA"
      else
        Shopify::CreateDiscountCode.call(client: @client, title: "Troca - Pedido #{@request.shopify_order_number}",
                                         amount: amount, expires_in: validity, customer_id: customer_id,
                                         combines: @config.credit_combines_with_discounts?)
      end
      raise Shopify::GraphqlCall::Error, "a Shopify recusou a criação do crédito" if code.blank?

      @request.update!(coupon_code: code, credit_kind: @config.credit_type, credit_amount: amount)
      log("Crédito de #{money(amount)} gerado (#{ExchangeConfig::CREDIT_TYPES[@config.credit_type]}).", public: true)
    rescue StandardError => e
      fail!("Não foi possível gerar o crédito: #{e.message}")
    end

    def issue_refunds(totals)
      details = @request.refund_details || {}
      manual = Array(details["gateways"]).any? { |g| g.to_s.match?(MANUAL_GATEWAYS) }

      if totals[:refund].positive?
        if manual
          register_manual_refund(totals[:refund], details)
        else
          refund_on_shopify(totals, details)
        end
      end
      register_manual_refund(totals[:refund_extra], details, note: "Diferença de preço a favor do cliente") if totals[:refund_extra].positive?
      Exchange::Notify.call(@request, "refunded") if @request.exchange_refunds.any?
    end

    def refund_on_shopify(totals, details)
      items = @request.items_with("refund").filter_map do |item|
        { line_item_id: item.shopify_line_item_id, quantity: item.quantity } if item.shopify_line_item_id.present?
      end
      shipping = refund_original_shipping? ? details["order_shipping"].to_f : 0
      result = Shopify::CreateRefund.call(client: @client, order_id: @request.shopify_order_id, items: items,
                                          shipping_amount: shipping, deduct: totals[:shipping_deducted],
                                          note: "Troca/devolução #{@request.public_code}")
      @request.exchange_refunds.create!(method: "card", amount: result.amount.positive? ? result.amount : totals[:refund],
                                        status: "done", shopify_refund_id: result.refund_id,
                                        notes: "Estornado pela Shopify (#{result.gateway || 'forma original'})")
      log("Reembolso de #{money(result.amount)} feito pela Shopify na forma de pagamento original.", public: true)
    rescue StandardError => e
      @request.exchange_refunds.create!(method: "other", amount: totals[:refund], status: "failed",
                                        notes: "Falha na Shopify: #{e.message}")
      fail!("Reembolso não foi feito pela Shopify: #{e.message}. Registre o andamento manualmente.")
    end

    def register_manual_refund(amount, details, note: nil)
      method = Array(details["gateways"]).join(" ").match?(/boleto/i) ? "boleto" : "pix"
      notes = [ note, ("Chave Pix informada: #{details['pix_key']}" if details["pix_key"].present?) ].compact.join(" · ")
      @request.exchange_refunds.create!(method: method, amount: amount, status: "pending", notes: notes.presence)
      log("Reembolso de #{money(amount)} via #{ExchangeRefund::METHODS[method]} aguardando pagamento pela equipe.", public: true)
    end

    def refund_original_shipping?
      details = @request.refund_details || {}
      return false unless details["all_items"]

      @config.refund_original_shipping? || @request.exchange_request_items.any? { |i| i.reason == "arrependimento" }
    end

    def issue_replacement(charge)
      orders = Shopify::ReplacementOrder.new(@client)
      draft = orders.draft(request: @request, lines: self.class.replacement_lines(@request), charge: charge,
                           draft_id: @request.replacement_draft_order_id)
      @request.update!(replacement_draft_order_id: draft["id"])

      if charge.positive?
        url = orders.send_invoice(draft["id"])
        @request.update!(invoice_url: url)
        log("Complemento de #{money(charge)} enviado ao cliente para pagamento (#{draft['name']}). " \
            "A nova peça é enviada após o pagamento.", public: true)
      else
        order = orders.complete(draft["id"])
        @request.update!(replacement_order_name: order&.dig("name"))
        log("Pedido de reposição #{order&.dig('name')} criado na Shopify.", public: true)
      end
    rescue StandardError => e
      fail!("Não foi possível criar o pedido de reposição: #{e.message}")
    end

    def fail!(message)
      @errors << message
      log(message, kind: "error")
    end

    def log(message, kind: "resolution", public: false)
      @request.log!(kind, message, user: @user, public: public)
    end

    def money(value)
      ActiveSupport::NumberHelper.number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".")
    end
  end
end
