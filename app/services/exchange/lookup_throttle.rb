module Exchange
  # Limita buscas de pedido por IP na página pública (evita varredura de
  # número de pedido + e-mail).
  class LookupThrottle
    LIMIT = 10
    WINDOW = 5.minutes

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    def allow?(key)
      count = @cache.increment("exchange_lookup:#{key}", 1, expires_in: WINDOW)
      count.present? && count <= LIMIT
    end
  end
end
