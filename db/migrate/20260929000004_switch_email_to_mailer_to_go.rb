# E-mails saem pelo SMTP do Mailer To Go. Domínios próprios das lojas são
# cadastrados no painel do Mailer To Go pela equipe Mewtda (não há API), que
# cola aqui os registros DNS para a loja e marca o domínio como verificado.
class SwitchEmailToMailerToGo < ActiveRecord::Migration[8.1]
  def change
    rename_column :clients, :ses_verification_status, :email_domain_status
    rename_column :clients, :ses_verified_at, :email_domain_verified_at
    remove_column :clients, :ses_dkim_tokens, :string, array: true, default: [], null: false
    add_column :clients, :email_dns_records, :text
    change_column_default :clients, :email_from_local, from: "naoresponda", to: "trocas"
  end
end
