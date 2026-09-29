module Exchange
  # Aprova a solicitação e, se houver itens de troca, gera um cupom na
  # Shopify no valor desses itens.
  class Approve
    def initialize(exchange_request)
      @exchange_request = exchange_request
    end

    def call
      @exchange_request.update!(status: :approved, coupon_code: generate_coupon)
      SendExchangeEmailJob.perform_later(exchange_request_id: @exchange_request.id, kind: "approved")
      @exchange_request
    end

    private

    def generate_coupon
      total = @exchange_request.troca_total
      return nil if total <= 0

      client = @exchange_request.client
      Shopify::CreateDiscountCode.call(
        client: client,
        title: "Troca - Pedido #{@exchange_request.shopify_order_number}",
        amount: total,
        expires_in: client.exchange_config.coupon_validity_days.days
      )
    end
  end
end
