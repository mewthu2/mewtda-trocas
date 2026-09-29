# Domínio de envio dos e-mails da loja na SES (cadastro, verificação DKIM e
# remetente), em Configuração > Comunicação.
class EmailDomainsController < ApplicationController
  before_action :require_client!

  def create
    return redirect_back_with(alert: "Credenciais da SES não configuradas no servidor.") unless Ses::DomainIdentity.configured?

    Ses::DomainIdentity.new(current_client).register!(params[:domain])
    redirect_back_with(notice: "Domínio cadastrado. Crie os registros DNS abaixo e clique em Verificar.")
  rescue StandardError => e
    redirect_back_with(alert: "Não foi possível cadastrar o domínio: #{e.message}")
  end

  # Atualiza remetente e/ou consulta a verificação na SES.
  def update
    if params.key?(:client)
      unless current_client.update(params.require(:client).permit(:email_from_name, :email_from_local, :email_reply_to))
        return redirect_back_with(alert: current_client.errors.full_messages.to_sentence)
      end
    end
    Ses::DomainIdentity.new(current_client).refresh! if params[:check] && Ses::DomainIdentity.configured?
    message = current_client.ses_domain_verified? ? "Domínio verificado — e-mails liberados." : "Dados salvos. Verificação ainda pendente no DNS."
    redirect_back_with(notice: params[:check] ? message : "Remetente salvo.")
  rescue StandardError => e
    redirect_back_with(alert: "Falha ao consultar a SES: #{e.message}")
  end

  def destroy
    Ses::DomainIdentity.new(current_client).remove!
    redirect_back_with(notice: "Domínio removido.")
  rescue StandardError => e
    redirect_back_with(alert: "Falha ao remover: #{e.message}")
  end

  private

  def redirect_back_with(flash_hash)
    redirect_to email_templates_exchange_config_path, flash: flash_hash, status: :see_other
  end
end
