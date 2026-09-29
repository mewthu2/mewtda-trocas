# Remetente e domínio próprio de envio da loja (Configuração > Comunicação).
# O Mailer To Go não tem API de domínios: a loja pede o domínio aqui, um
# administrador da Mewtda cadastra no painel do Mailer To Go, cola os registros
# DNS para a loja e marca como verificado quando o painel confirmar.
class EmailDomainsController < ApplicationController
  before_action :require_client!
  before_action :require_admin!, only: :verify

  def create
    domain = params[:domain].to_s.strip.downcase.sub(%r{\Ahttps?://}, "").delete_suffix("/")
    if domain.match?(/\A([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}\z/)
      current_client.update!(email_sending_domain: domain, email_domain_status: "pending", email_domain_verified_at: nil)
      redirect_back_with(notice: "Domínio enviado. A equipe Mewtda vai cadastrar e mostrar aqui os registros DNS.")
    else
      redirect_back_with(alert: "Informe um domínio válido, ex.: sualoja.com.br")
    end
  end

  def update
    if current_client.update(params.require(:client).permit(:email_from_name, :email_from_local, :email_reply_to))
      redirect_back_with(notice: "Remetente salvo.")
    else
      redirect_back_with(alert: current_client.errors.full_messages.to_sentence)
    end
  end

  # Só administradores: registros DNS do Mailer To Go e status de verificação.
  def verify
    attrs = { email_dns_records: params[:email_dns_records].to_s.strip.presence }
    if params.key?(:verified)
      verified = params[:verified] == "1"
      attrs.merge!(email_domain_status: verified ? "verified" : "pending", email_domain_verified_at: (Time.current if verified))
    end
    current_client.update!(attrs)
    redirect_back_with(notice: current_client.email_domain_verified? ? "Domínio verificado — e-mails saem pelo domínio da loja." : "Dados do domínio salvos.")
  end

  def destroy
    current_client.update!(email_sending_domain: nil, email_domain_status: "unverified", email_domain_verified_at: nil,
                           email_dns_records: nil)
    redirect_back_with(notice: "Domínio removido. Os e-mails voltam a sair pelo domínio padrão.")
  end

  private

  def require_admin!
    redirect_back_with(alert: "Só a equipe Mewtda pode verificar domínios.") unless current_user.admin?
  end

  def redirect_back_with(flash_hash)
    redirect_to email_templates_exchange_config_path, flash: flash_hash, status: :see_other
  end
end
