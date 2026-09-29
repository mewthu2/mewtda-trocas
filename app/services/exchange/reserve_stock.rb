module Exchange
  # Reserva as peças de reposição num pedido rascunho da Shopify
  # (reserveInventoryUntil), no momento escolhido pela loja.
  class ReserveStock
    def initialize(request)
      @request = request
      @config = request.config
    end

    def call_if(moment)
      return unless @config.reserve_stock_on == moment
      return if @request.replacement_items.empty?

      reserve_until = Time.current + @config.reserve_hours.hours
      draft = Shopify::ReplacementOrder.new(@request.client).draft(
        request: @request, lines: Exchange::Resolve.replacement_lines(@request), reserve_until: reserve_until,
        draft_id: @request.replacement_draft_order_id
      )
      @request.update!(replacement_draft_order_id: draft["id"], stock_reserved_until: reserve_until)
      @request.log!("stock_reserved", "Estoque da nova peça reservado até #{I18n.l(reserve_until, format: :short)} (#{draft['name']}).")
    rescue StandardError => e
      @request.log!("error", "Não foi possível reservar o estoque na Shopify: #{e.message}")
    end
  end
end
