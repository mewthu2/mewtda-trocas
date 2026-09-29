class CurrentClientsController < ApplicationController
  def update
    return head :forbidden unless current_user.admin?

    client = Client.find(params[:client_id])
    session[:client_id] = client.id
    redirect_to exchange_requests_path, notice: "Loja alterada para #{client.name}.", status: :see_other
  end
end
