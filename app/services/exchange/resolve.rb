module Exchange
  # Executa o resultado depois da aprovação (ou da conferência, conforme a loja):
  #   - cupom: um cupom de uso único na Shopify no valor dos itens;
  #   - devolução do dinheiro: registrada como pendente para a equipe fazer o
  #     estorno, Pix ou transferência e anexar o comprovante;
  #   - reparo: fica com a equipe (registrado no histórico).
  # Frete pago pelo cliente é descontado do cupom e, se sobrar, da devolução.
  class Resolve
    def initialize(request, user: nil)
      @request = request
      @config = request.config
      @user = user
      @errors = []
    end

    def call
      coupon, refund = amounts
      issue_coupon(coupon) if coupon.positive? && @request.coupon_code.blank?
      register_refund(refund) if refund.positive? && @request.exchange_refunds.none?
      log("Reparo: a equipe deve consertar e reenviar o produto ao cliente.") if @request.items_with("repair").any?
      @errors.empty?
    end

    def errors
      @errors
    end

    private

    def amounts
      coupon = @request.coupon_items_total
      refund = @request.refund_total
      shipping = @request.customer_pays_shipping? ? @request.shipping_cost.to_f : 0

      from_coupon = [ coupon, shipping ].min
      from_refund = [ refund, shipping - from_coupon ].min
      [ (coupon - from_coupon).round(2), (refund - from_refund).round(2) ]
    end

    def issue_coupon(amount)
      code = Shopify::CreateDiscountCode.call(
        client: @request.client, title: "Troca - Pedido #{@request.shopify_order_number}", amount: amount,
        expires_in: @config.coupon_validity_days.days,
        customer_id: (@request.shopify_customer_id if @config.credit_link_customer?),
        combines: @config.coupon_combines_with_discounts?
      )
      raise "a Shopify recusou a criação do cupom" if code.blank?

      @request.update!(coupon_code: code, credit_amount: amount)
      log("Cupom #{code} de #{money(amount)} gerado.", public: true)
    rescue StandardError => e
      fail!("Não foi possível gerar o cupom: #{e.message}. Crie o cupom manualmente na Shopify se preciso.")
    end

    def register_refund(amount)
      method = @request.refund_method.presence_in(ExchangeRefund::METHODS.keys) || "estorno"
      @request.exchange_refunds.create!(method: method, amount: amount, status: "pending")
      log("Devolução de #{money(amount)} por #{ExchangeRefund::METHODS[method].downcase} aguardando a equipe.", public: true)
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
