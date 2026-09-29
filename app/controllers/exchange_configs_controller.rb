class ExchangeConfigsController < ApplicationController
  SECTIONS = %w[edit rules reasons resolutions shipping email_templates].freeze

  before_action :require_client!
  before_action :load_exchange_config

  def edit; end
  def rules; end
  def reasons; end
  def resolutions; end
  def shipping; end
  def email_templates; end

  def update
    purge_removed_attachments
    section = params[:return_to].presence_in(SECTIONS) || "edit"

    if @exchange_config.update(exchange_config_params)
      redirect_to section_path(section), notice: "Configuração salva com sucesso.", status: :see_other
    else
      render section, status: :unprocessable_entity
    end
  end

  def test_correios
    contract = @exchange_config.carrier_contract
    if contract&.correios? && contract.username.present?
      client = Correios::Client.new(contract)
      client.authenticate!
      price = client.price(service: contract.default_service, from_zip: contract.sender_zip, weight_g: contract.package_weight_g)
      flash[:notice] = "Conexão com os Correios OK. #{contract.service_label}: R$ #{format('%.2f', price.to_f).tr('.', ',')} (mesmo CEP, pacote padrão)."
    else
      flash[:alert] = "Preencha e salve o contrato dos Correios antes de testar."
    end
    redirect_to shipping_exchange_config_path, status: :see_other
  rescue Correios::Client::Error, StandardError => e
    redirect_to shipping_exchange_config_path, alert: "Falha na conexão: #{e.message}", status: :see_other
  end

  private

  def section_path(section)
    section == "edit" ? edit_exchange_config_path : public_send(:"#{section}_exchange_config_path")
  end

  def load_exchange_config
    @exchange_config = current_client.exchange_config || current_client.build_exchange_config(accent_color: "#1b873f")
    @exchange_config.build_carrier_contract(carrier: "correios") unless @exchange_config.carrier_contract
  end

  def purge_removed_attachments
    return unless @exchange_config.persisted?

    @exchange_config.logo.purge if params.dig(:exchange_config, :remove_logo) == "1"
    ExchangeConfig::EMAIL_KINDS.each do |kind|
      @exchange_config.email_image(kind).purge if params.dig(:exchange_config, :"remove_#{kind}_email_image") == "1"
    end
  end

  def exchange_config_params
    email_fields = ExchangeConfig::EMAIL_KINDS.flat_map { |kind| %I[#{kind}_email_subject #{kind}_email_body #{kind}_email_image] } +
                   ExchangeConfig::EXTRA_EMAIL_KINDS.flat_map { |kind| %I[#{kind}_email_subject #{kind}_email_body] } +
                   ExchangeConfig::MESSAGE_KINDS.map { |kind| :"#{kind}_whatsapp_body" }

    params.require(:exchange_config).permit(
      :active, :company_name, :accent_color, :instructions, :logo, :support_email, :support_whatsapp, :support_hours,
      :return_window_days, :window_base, :defect_window_days,
      :require_original_tag, :require_accessories, :require_packaging,
      :store_drop_off_addresses, :free_shipping_first_attempt, :free_shipping_above, :customer_shipping_flat_fee,
      :price_basis, :higher_price_action, :lower_price_action, :reserve_stock_on, :reserve_hours,
      :auto_approve, :auto_approve_max_value, :abuse_max_requests, :abuse_window_days, :resolve_on,
      :refund_original_shipping, :credit_type, :coupon_validity_days, :credit_combines_with_discounts, :credit_link_customer,
      :email_enabled, :whatsapp_enabled, :tracking_page_enabled, :analysis_sla_days, :refund_sla_days,
      *email_fields,
      return_modes: [],
      exchange_reasons_attributes: [ :id, :_destroy, :label, :key, :category, :active, :requires_photo, :manual_review,
                                     :shipping_payer, :questions, :position, { resolutions: [] } ],
      exchange_rules_attributes: %i[id _destroy rule_type target value days starts_on ends_on note],
      shipping_rules_attributes: %i[id _destroy zip_start zip_end max_weight_g service_code position],
      carrier_contract_attributes: %i[id carrier active username access_code posting_card contract_number administrative_code
                                      default_service sender_name sender_document sender_phone sender_email sender_zip
                                      sender_street sender_number sender_complement sender_district sender_city sender_state
                                      package_weight_g package_length_cm package_width_cm package_height_cm authorization_days
                                      manual_instructions]
    ).tap do |permitted|
      # Campo de senha em branco = manter o código de acesso atual.
      contract = permitted[:carrier_contract_attributes]
      contract.delete(:access_code) if contract && contract[:access_code].blank?
    end
  end
end
