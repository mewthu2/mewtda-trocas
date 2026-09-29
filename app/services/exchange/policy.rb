module Exchange
  # Decide o que cada item do pedido pode pedir, a partir da configuração da
  # loja e dos mínimos legais:
  #   - troca voluntária: prazo da loja (ou exceção por produto/coleção/período),
  #     exceto itens excluídos por regra;
  #   - arrependimento: 7 dias da entrega, vale mesmo para itens excluídos;
  #   - vício / erro no pedido: prazo de vício (padrão 90 dias).
  # Só mostra resultados possíveis no caso (ex.: "outro tamanho" só se houver
  # outra variante disponível).
  class Policy
    ItemOptions = Struct.new(:index, :item, :reasons, :remaining, :message, keyword_init: true) do
      def available?
        reasons.any? && remaining.positive?
      end

      def reason(key)
        reasons.find { |option| option[:reason].key == key.to_s }
      end
    end

    attr_reader :config, :order

    # already_requested: { line_item_id (ou índice) => quantidade já pedida }
    def initialize(config, order, already_requested: {})
      @config = config
      @order = order
      @already_requested = already_requested
    end

    def status
      return :cancelled if order[:cancelled]
      return :not_fulfilled if base_date.blank?

      items.any?(&:available?) ? :ok : :expired
    end

    def base_date
      @base_date ||= if config.window_base == "delivery"
        order[:delivered_at] || order[:fulfilled_at]
      else
        order[:fulfilled_at]
      end
    end

    def days_since
      @days_since ||= base_date ? (Date.current - base_date.to_date).to_i : nil
    end

    def items
      @items ||= order[:items].each_with_index.map { |item, index| options_for(item, index) }
    end

    def item(index)
      items[index.to_i]
    end

    def voluntary_window_days(item)
      matched = config.exchange_rules.select { |rule| rule.rule_type == "window" && rule.matches?(order, item) }
      matched.any? ? matched.map(&:days).max : config.return_window_days
    end

    def excluded?(item)
      config.exchange_rules.any? { |rule| rule.rule_type == "exclude" && rule.matches?(order, item) }
    end

    private

    def options_for(item, index)
      remaining = item[:quantity].to_i - @already_requested.fetch(item[:line_item_id] || index, 0).to_i
      return ItemOptions.new(index: index, item: item, reasons: [], remaining: 0, message: "Já solicitado") if remaining <= 0

      reasons = config.active_reasons.filter_map { |reason| reason_option(reason, item) }
      message = nil
      if reasons.empty?
        message = excluded?(item) ? "Este produto não aceita troca" : "Prazo encerrado"
      end
      ItemOptions.new(index: index, item: item, reasons: reasons, remaining: remaining, message: message)
    end

    def reason_option(reason, item)
      deadline = deadline_for(reason, item)
      return nil if deadline.nil? || days_since.nil? || days_since > deadline

      resolutions = reason.resolutions.select { |resolution| resolution_possible?(resolution, reason, item) }
      return nil if resolutions.empty?

      { reason: reason, resolutions: resolutions, days_left: deadline - days_since }
    end

    def deadline_for(reason, item)
      case reason.category
      when "voluntary" then excluded?(item) ? nil : voluntary_window_days(item)
      when "regret" then ExchangeConfig::REGRET_WINDOW_DAYS
      else config.defect_window_days
      end
    end

    def resolution_possible?(resolution, reason, item)
      case resolution
      when "other_variant" then other_variants(item).any?
      when "same_variant" then same_variant_available?(item) || reason.legal?
      else true
      end
    end

    def same_variant_available?(item)
      variant = Array(item[:variants]).find { |v| v[:id] == item[:variant_id] }
      variant.nil? || variant[:available] != false
    end

    public

    def other_variants(item)
      Array(item[:variants]).select { |v| v[:id] != item[:variant_id] && v[:available] != false }
    end
  end
end
