# Cliente da API REST dos Correios (api.correios.com.br) para contratos:
#   - token: autentica com usuário do Meu Correios + código de acesso e cartão
#     de postagem (Basic auth);
#   - preço e prazo nacionais por serviço;
#   - pré-postagem com logística reversa: gera o código de autorização/objeto
#     que o cliente leva à agência (ou que a coleta usa).
class Correios::Client
  BASE_URL = "https://api.correios.com.br".freeze

  class Error < StandardError; end

  def initialize(contract)
    @contract = contract
  end

  def authenticate!
    response = HTTParty.post(
      "#{BASE_URL}/token/v1/autentica/cartaopostagem",
      basic_auth: { username: @contract.username.to_s, password: @contract.access_code.to_s },
      headers: json_headers,
      body: { numero: @contract.posting_card }.to_json,
      timeout: 15
    )
    raise Error, error_message(response) unless response.success? && response.parsed_response["token"].present?

    @token = response.parsed_response["token"]
  end

  def price(service:, from_zip:, weight_g:)
    body = get("/preco/v1/nacional/#{service}", {
      cepOrigem: digits(from_zip), cepDestino: @contract.sender_zip, psObjeto: [ weight_g.to_i, 1 ].max,
      tpObjeto: 2, comprimento: @contract.package_length_cm, largura: @contract.package_width_cm,
      altura: @contract.package_height_cm
    })
    parse_money(body["pcFinal"])
  end

  def deadline_days(service:, from_zip:)
    get("/prazo/v1/nacional/#{service}", { cepOrigem: digits(from_zip), cepDestino: @contract.sender_zip })["prazoEntrega"]&.to_i
  end

  # Pré-postagem reversa: o remetente é o cliente final e o destinatário é a loja.
  def create_reverse_posting(request:, service:, weight_g:, pickup: false)
    payload = {
      idCorreios: @contract.username,
      codigoServico: service,
      numeroCartaoPostagem: @contract.posting_card,
      logisticaReversa: "S",
      dataValidadeLogReversa: (Date.current + @contract.authorization_days).iso8601,
      solicitarColeta: pickup ? "S" : "N",
      remetente: customer_party(request),
      destinatario: store_party,
      pesoInformado: [ weight_g.to_i, 1 ].max.to_s,
      codigoFormatoObjetoInformado: "2",
      comprimentoInformado: @contract.package_length_cm.to_s,
      larguraInformada: @contract.package_width_cm.to_s,
      alturaInformada: @contract.package_height_cm.to_s,
      observacao: "Troca/devolução #{request.public_code} - pedido #{request.shopify_order_number}"
    }
    body = post("/prepostagem/v1/prepostagens", payload)
    {
      authorization_code: body["codigoAutorizacao"].presence || body["numeroAutorizacao"].presence || body["id"].to_s,
      tracking_code: body["codigoObjeto"].presence,
      expires_at: (body["dataValidadeLogReversa"].presence && Date.parse(body["dataValidadeLogReversa"])) ||
                  (Date.current + @contract.authorization_days)
    }
  end

  private

  def get(path, query)
    response = HTTParty.get("#{BASE_URL}#{path}", query: query, headers: auth_headers, timeout: 15)
    raise Error, error_message(response) unless response.success?

    response.parsed_response
  end

  def post(path, payload)
    response = HTTParty.post("#{BASE_URL}#{path}", body: payload.to_json, headers: auth_headers, timeout: 20)
    raise Error, error_message(response) unless response.success?

    response.parsed_response
  end

  def auth_headers
    authenticate! unless @token
    json_headers.merge("Authorization" => "Bearer #{@token}")
  end

  def json_headers
    { "Content-Type" => "application/json", "Accept" => "application/json" }
  end

  def customer_party(request)
    phone = digits(request.customer_phone)
    {
      nome: request.customer_display_name.first(50),
      email: request.customer_email,
      dddCelular: phone&.first(2),
      celular: phone&.from(2),
      endereco: { cep: digits(request.customer_zip) }
    }.compact
  end

  def store_party
    c = @contract
    {
      nome: c.sender_name.to_s.first(50),
      cpfCnpj: c.sender_document,
      email: c.sender_email,
      dddTelefone: digits(c.sender_phone)&.first(2),
      telefone: digits(c.sender_phone)&.from(2),
      endereco: {
        cep: c.sender_zip, logradouro: c.sender_street, numero: c.sender_number, complemento: c.sender_complement,
        bairro: c.sender_district, cidade: c.sender_city, uf: c.sender_state
      }.compact
    }.compact
  end

  def digits(value)
    value.to_s.gsub(/\D/, "").presence
  end

  def parse_money(value)
    value.to_s.delete(".").tr(",", ".").to_f if value.present?
  end

  def error_message(response)
    body = response.parsed_response
    messages = body.is_a?(Hash) ? Array(body["msgs"]).presence || [ body["mensagem"] || body["message"] ].compact : []
    "Correios (HTTP #{response.code}): #{messages.join('; ').presence || response.body.to_s.first(200)}"
  end
end
