# Contato de atendimento da loja, mostrado no rodapé da página pública.
class AddSupportContactsToExchangeConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :exchange_configs, :support_email, :string
    add_column :exchange_configs, :support_whatsapp, :string
    add_column :exchange_configs, :support_hours, :string
  end
end
