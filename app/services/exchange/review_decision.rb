module Exchange
  # Decide se a solicitação pode ser aprovada automaticamente ou precisa de
  # análise humana (motivo que exige análise, foto, valor alto ou suspeita de
  # abuso — muitas solicitações do mesmo e-mail em pouco tempo).
  class ReviewDecision
    def initialize(request, reasons)
      @request = request
      @reasons = reasons
      @config = request.config
    end

    def reasons
      @reasons_for_review ||= [].tap do |list|
        list << "auto_off" unless @config.auto_approve?
        list << "manual_reason" if @reasons.any?(&:manual_review?)
        list << "photo" if @request.exchange_request_items.any? { |item| item.photo.attached? }
        list << "value" if over_limit?
        list << "abuse" if abuse?
      end
    end

    def auto_approve?
      reasons.empty?
    end

    def abuse?
      recent = @request.client.exchange_requests
                       .where("LOWER(customer_email) = ?", @request.customer_email.to_s.downcase)
                       .where(created_at: @config.abuse_window_days.days.ago..)
                       .where.not(id: @request.id)
                       .count
      recent >= @config.abuse_max_requests
    end

    private

    def over_limit?
      limit = @config.auto_approve_max_value
      limit.present? && @request.total > limit
    end
  end
end
