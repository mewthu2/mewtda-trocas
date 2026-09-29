# Chaves do ActiveRecord::Encryption (senha da API dos Correios) derivadas do
# secret_key_base — não precisam de variáveis extras no Heroku.
Rails.application.config.to_prepare do
  generator = Rails.application.key_generator
  ActiveRecord::Encryption.configure(
    primary_key: generator.generate_key("active_record_encryption/primary_key", 32).unpack1("H*"),
    deterministic_key: generator.generate_key("active_record_encryption/deterministic_key", 32).unpack1("H*"),
    key_derivation_salt: generator.generate_key("active_record_encryption/key_derivation_salt", 32).unpack1("H*")
  )
end
