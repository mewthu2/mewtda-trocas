# Mesma tabela users do mewtda-painel: quem acessa o painel entra aqui com o
# mesmo e-mail e senha. Cadastro de usuários continua sendo feito no painel.
class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :validatable

  belongs_to :profile, optional: true
  belongs_to :client, optional: true

  def admin?
    profile_id == Profile::ADMIN
  end

  def affiliate?
    profile_id == Profile::AFFILIATE
  end

  def display_name
    name.presence || email
  end
end
