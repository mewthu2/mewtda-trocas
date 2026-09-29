class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :block_affiliates!

  helper_method :current_client, :selectable_clients

  layout -> { devise_controller? ? "auth" : "application" }

  private

  # Admins escolhem a loja no seletor do topo; os demais veem só a própria.
  def current_client
    return @current_client if defined?(@current_client)

    client_id = current_user.admin? ? (session[:client_id] || current_user.client_id) : current_user.client_id
    @current_client = Client.find_by(id: client_id)
  end

  def selectable_clients
    @selectable_clients ||= current_user.admin? ? Client.where(active: true).order(:name) : Client.none
  end

  def require_client!
    return if current_client

    render "shared/no_client", status: :ok
  end

  def block_affiliates!
    return unless user_signed_in? && current_user.affiliate?

    sign_out current_user
    redirect_to new_user_session_path, alert: "Seu perfil não tem acesso à central de trocas."
  end

  def after_sign_in_path_for(_user)
    authenticated_root_path
  end
end
