# Remetente padrão dos e-mails: quero-trocar@<domínio>, com o nome da loja.
class DefaultSenderQueroTrocar < ActiveRecord::Migration[8.1]
  def up
    change_column_default :clients, :email_from_local, "quero-trocar"
    execute "UPDATE clients SET email_from_local = 'quero-trocar' WHERE email_from_local IN ('naoresponda', 'trocas') OR email_from_local IS NULL"
  end

  def down
    change_column_default :clients, :email_from_local, "trocas"
  end
end
