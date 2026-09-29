# Dados de demonstração para desenvolvimento local — não rode em produção.
abort "Seeds são só para desenvolvimento." if Rails.env.production?

Profile.find_or_create_by!(id: Profile::ADMIN) { |p| p.name = "Admin" }
Profile.find_or_create_by!(id: Profile::USER) { |p| p.name = "Usuário" }
Profile.find_or_create_by!(id: Profile::AFFILIATE) { |p| p.name = "Afiliado" }

client = Client.find_or_create_by!(name: "Loja Demo") do |c|
  c.email = "contato@lojademo.com.br"
  c.email_sending_domain = "lojademo.com.br"
end
Client.find_or_create_by!(name: "Outra Loja") { |c| c.email = "contato@outraloja.com.br" }

User.find_or_create_by!(email: "admin@mewtda.com") do |u|
  u.name = "Admin Mewtda"
  u.password = "senha123"
  u.profile_id = Profile::ADMIN
  u.client = client
end

config = client.exchange_config || client.create_exchange_config!(
  active: true, company_name: "Loja Demo", accent_color: "#1b873f",
  instructions: "Você tem até 7 dias após o recebimento para devolver, e até 30 dias para trocar.",
  return_window_days: 7, coupon_validity_days: 30
)

if client.exchange_requests.none?
  samples = [
    [ "#1042", "Maria Silva", "maria@example.com", :pending, [ [ "Vestido Midi Linho", "M / Verde", 289.9, :troca, "tamanho_nao_serviu" ] ] ],
    [ "#1038", "João Souza", "joao@example.com", :approved, [ [ "Camisa Oxford", "G / Branca", 199.0, :troca, "nao_gostei" ], [ "Bermuda Sarja", "42", 159.0, :devolucao, "arrependimento" ] ] ],
    [ "#1031", nil, "ana@example.com", :completed, [ [ "Tênis Casual", "37", 349.0, :devolucao, "produto_errado" ] ] ],
    [ "#1027", "Carla Dias", "carla@example.com", :rejected, [ [ "Blusa Tricot", "P", 129.9, :troca, "outro" ] ] ]
  ]
  samples.each_with_index do |(number, name, email, status, items), i|
    request = client.exchange_requests.create!(
      shopify_order_id: "55000#{i}", shopify_order_number: number, customer_name: name,
      customer_email: email, status: status, created_at: i.days.ago,
      coupon_code: (status == :approved ? "RECDEMO#{i}X" : nil)
    )
    items.each do |product, variant, price, kind, reason|
      request.exchange_request_items.create!(product_name: product, variant_title: variant, price: price,
                                             quantity: 1, kind: kind, reason: reason, sku: product.parameterize)
    end
  end
end

puts "Login: admin@mewtda.com / senha123 — página pública: /troca/#{config.slug}"
