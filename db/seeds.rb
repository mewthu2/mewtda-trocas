# Dados de demonstração para desenvolvimento local — não rode em produção.
abort "Seeds são só para desenvolvimento." if Rails.env.production?

Profile.find_or_create_by!(id: Profile::ADMIN) { |p| p.name = "Admin" }
Profile.find_or_create_by!(id: Profile::USER) { |p| p.name = "Usuário" }
Profile.find_or_create_by!(id: Profile::AFFILIATE) { |p| p.name = "Afiliado" }

client = Client.find_or_create_by!(name: "Loja Demo") { |c| c.email = "contato@lojademo.com.br" }
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
  return_window_days: 30, coupon_validity_days: 30, support_whatsapp: "(16) 99199-7608"
)

if client.exchange_requests.none?
  samples = [
    [ "#1042", "Maria Silva", "maria@example.com", :pending, [ [ "Vestido Midi Linho", "M / Verde", 289.9, "coupon", "tamanho", "Tamanho não serviu" ] ] ],
    [ "#1038", "João Souza", "joao@example.com", :approved, [ [ "Camisa Oxford", "G / Branca", 199.0, "coupon", "nao_gostei", "Não gostei do produto" ], [ "Bermuda Sarja", "42", 159.0, "refund", "arrependimento", "Desisti da compra (arrependimento)" ] ] ],
    [ "#1031", nil, "ana@example.com", :completed, [ [ "Tênis Casual", "37", 349.0, "refund", "produto_errado", "Recebi um produto diferente do pedido" ] ] ],
    [ "#1027", "Carla Dias", "carla@example.com", :rejected, [ [ "Blusa Tricot", "P", 129.9, "coupon", "cor", "Quero outra cor" ] ] ]
  ]
  samples.each_with_index do |(number, name, email, status, items), i|
    request = client.exchange_requests.create!(
      shopify_order_id: "55000#{i}", shopify_order_number: number, customer_name: name,
      customer_email: email, status: status, created_at: i.days.ago, return_mode: "agencia", shipping_payer: "store",
      refund_method: ("pix" if items.any? { |item| item[3] == "refund" }),
      coupon_code: (status == :approved ? "RECDEMO#{i}X" : nil)
    )
    items.each do |product, variant, price, resolution, reason, label|
      request.exchange_request_items.create!(product_name: product, variant_title: variant, price: price, quantity: 1,
                                             resolution: resolution, reason: reason, reason_label: label, sku: product.parameterize)
    end
    request.log!("requested", "Solicitação recebida.", public: true)
  end
end

puts "Login: admin@mewtda.com / senha123 — página pública: /troca/#{config.slug}"
