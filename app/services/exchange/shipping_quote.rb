module Exchange
  # Define quem paga o frete reverso e quanto custa.
  #   - motivo legal (arrependimento, vício, erro da loja): sempre a loja;
  #   - motivo voluntário: o que o motivo diz, com duas exceções a favor do
  #     cliente — primeira troca grátis e pedidos acima de um valor.
  # Quando o cliente paga, o valor vem da cotação dos Correios (ou da taxa fixa
  # configurada) e é descontado do cupom ou da devolução do dinheiro.
  class ShippingQuote
    Result = Struct.new(:payer, :service, :cost, :note, keyword_init: true)

    def initialize(config, order:, reasons:, weight_g:, zip:, previous_requests: 0, correios: nil)
      @config = config
      @order = order
      @reasons = reasons
      @weight_g = weight_g
      @zip = zip
      @previous_requests = previous_requests
      @correios = correios
    end

    def call
      payer, note = decide_payer
      service = service_code
      cost = payer == "customer" ? customer_cost(service) : nil
      Result.new(payer: payer, service: service, cost: cost, note: note)
    end

    private

    def decide_payer
      return [ "store", "Frete por conta da loja (garantido por lei)" ] if @reasons.any?(&:legal?)
      return [ "store", "Frete grátis" ] if @reasons.all? { |reason| reason.shipping_payer == "store" }
      return [ "store", "Primeira troca com frete grátis" ] if @config.free_shipping_first_attempt? && @previous_requests.zero?

      threshold = @config.free_shipping_above
      order_total = @order[:items].sum { |item| item[:price].to_f * item[:quantity].to_i }
      return [ "store", "Frete grátis para pedidos acima de R$ #{format('%.2f', threshold)}" ] if threshold.present? && order_total >= threshold

      [ "customer", "Frete reverso por conta do cliente" ]
    end

    def service_code
      rule = @config.shipping_rules.find { |r| r.matches?(zip: @zip, weight_g: @weight_g) }
      rule&.service_code || @config.carrier_contract&.default_service || "03301"
    end

    def customer_cost(service)
      return @config.customer_shipping_flat_fee.to_f if @config.customer_shipping_flat_fee.present?
      return nil unless @correios && @zip.present?

      @correios.price(service: service, from_zip: @zip, weight_g: @weight_g)
    rescue StandardError => e
      Rails.logger.error("[Exchange::ShippingQuote] #{e.class} #{e.message}")
      nil
    end
  end
end
