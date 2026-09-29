class ExchangeConfigsController < ApplicationController
  before_action :require_client!
  before_action :load_exchange_config

  def edit; end

  def email_templates; end

  def update
    purge_removed_attachments
    return_view = params[:return_to] == "email_templates" ? :email_templates : :edit

    if @exchange_config.update(exchange_config_params)
      path = return_view == :email_templates ? email_templates_exchange_config_path : edit_exchange_config_path
      redirect_to path, notice: "Configuração salva com sucesso.", status: :see_other
    else
      render return_view, status: :unprocessable_entity
    end
  end

  private

  def load_exchange_config
    @exchange_config = current_client.exchange_config || current_client.build_exchange_config(accent_color: "#1b873f")
  end

  def purge_removed_attachments
    return unless @exchange_config.persisted?

    @exchange_config.logo.purge if params.dig(:exchange_config, :remove_logo) == "1"
    ExchangeConfig::EMAIL_KINDS.each do |kind|
      @exchange_config.email_image(kind).purge if params.dig(:exchange_config, :"remove_#{kind}_email_image") == "1"
    end
  end

  def exchange_config_params
    params.require(:exchange_config).permit(
      :active, :company_name, :accent_color, :instructions, :return_window_days, :coupon_validity_days, :logo,
      *ExchangeConfig::EMAIL_KINDS.flat_map { |kind| %I[#{kind}_email_subject #{kind}_email_body #{kind}_email_image] }
    )
  end
end
