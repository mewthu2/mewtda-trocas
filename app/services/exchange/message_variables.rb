module Exchange
  # Variáveis disponíveis nos textos de e-mail e WhatsApp.
  class MessageVariables
    NAMES = %w[customer_name order_number request_code tracking_url coupon_code credit_amount return_code
               return_expires_at refund_amount invoice_url rejection_reason analysis_sla_days refund_sla_days].freeze

    def initialize(request)
      @request = request
    end

    def to_h
      r = @request
      config = r.config
      {
        "customer_name" => r.customer_name.to_s,
        "order_number" => r.shopify_order_number.to_s,
        "request_code" => r.public_code.to_s,
        "tracking_url" => tracking_url,
        "coupon_code" => r.coupon_code.to_s,
        "credit_amount" => money(r.credit_amount),
        "return_code" => r.return_authorization_code.to_s,
        "return_expires_at" => r.return_expires_at ? I18n.l(r.return_expires_at.to_date) : "",
        "refund_amount" => money(r.exchange_refunds.sum(&:amount)),
        "invoice_url" => r.invoice_url.to_s,
        "rejection_reason" => r.rejection_reason.to_s,
        "analysis_sla_days" => config&.analysis_sla_days.to_s,
        "refund_sla_days" => config&.refund_sla_days.to_s
      }
    end

    def interpolate(text)
      vars = to_h
      text.to_s.gsub(/\{\{\s*(\w+)\s*\}\}/) { vars.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
    end

    private

    def tracking_url
      config = @request.config
      return "" unless config&.tracking_page_enabled? && @request.public_code

      Rails.application.routes.url_helpers.public_exchange_tracking_url(
        config.slug, @request.public_code, host: ENV.fetch("APP_HOST", "localhost:3000"),
                                           protocol: Rails.env.production? ? "https" : "http"
      )
    end

    def money(value)
      return "" if value.blank?

      ActiveSupport::NumberHelper.number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".")
    end
  end
end
