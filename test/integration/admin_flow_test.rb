require "test_helper"

class AdminFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @client = create_client
    create_config(@client)
    @user = create_user(client: @client)
  end

  test "exige login" do
    get exchange_requests_path
    assert_redirected_to new_user_session_path
  end

  test "login com usuário do painel" do
    post user_session_path, params: { user: { email: @user.email, password: "senha123" } }
    assert_redirected_to authenticated_root_path
  end

  test "afiliado não entra" do
    affiliate = create_user(client: @client, profile_id: Profile::AFFILIATE, email: "afiliado@example.com")
    sign_in affiliate

    get exchange_requests_path
    assert_redirected_to new_user_session_path
  end

  test "lista, filtra e busca solicitações só da loja do usuário" do
    create_request(@client)
    create_request(create_client(name: "Outra"), items: [])
    sign_in @user

    get exchange_requests_path
    assert_response :success
    assert_select "tbody tr", 1

    get exchange_requests_path(status: "approved")
    assert_select "tbody tr", 0

    get exchange_requests_path(q: "maria")
    assert_select "tbody tr", 1
  end

  test "não acessa solicitação de outra loja" do
    other = create_request(create_client(name: "Outra"))
    sign_in @user

    get exchange_request_path(other)
    assert_response :not_found
  end

  test "rejeita e salva nota" do
    request = create_request(@client)
    sign_in @user

    get exchange_request_path(request)
    assert_response :success

    patch exchange_request_path(request), params: { status: "rejected" }
    assert request.reload.rejected?

    patch exchange_request_path(request), params: { internal_notes: "Cliente ligou" }
    assert_equal "Cliente ligou", request.reload.internal_notes
  end

  test "admin troca de loja" do
    admin = create_user(profile_id: Profile::ADMIN, email: "admin@example.com")
    other = create_client(name: "Outra")
    create_request(other)
    sign_in admin

    patch current_client_path, params: { client_id: other.id }
    follow_redirect!
    assert_select "tbody tr", 1
  end

  test "todas as abas da configuração e o guia abrem" do
    sign_in @user

    [ edit_exchange_config_path, rules_exchange_config_path, reasons_exchange_config_path, resolutions_exchange_config_path,
      shipping_exchange_config_path, email_templates_exchange_config_path, help_path ].each do |path|
      get path
      assert_response :success, path
      assert_select ".app-footer"
    end
  end

  test "salva configuração, motivos, regras, contrato e templates" do
    sign_in @user
    config = @client.exchange_config

    patch exchange_config_path, params: { exchange_config: { company_name: "Nova", accent_color: "#00aa00", support_email: "sac@loja.com" } }
    assert_redirected_to edit_exchange_config_path
    assert_equal "sac@loja.com", config.reload.support_email

    patch exchange_config_path, params: { return_to: "rules", exchange_config: {
      return_window_days: 10, require_original_tag: "1",
      exchange_rules_attributes: { "0" => { rule_type: "window", target: "collection", value: "Natal", days: 30,
                                            starts_on: "2026-11-01", ends_on: "2026-12-24" } }
    } }
    assert_redirected_to rules_exchange_config_path
    assert_equal 10, config.reload.return_window_days
    assert_equal "Natal", config.exchange_rules.sole.value

    reason = config.reason_for("cor")
    patch exchange_config_path, params: { return_to: "reasons", exchange_config: {
      exchange_reasons_attributes: { "0" => { id: reason.id, label: "Outra cor", resolutions: [ "", "refund" ] },
                                     "1" => { label: "Presente repetido", category: "voluntary", resolutions: [ "coupon" ] } }
    } }
    assert_redirected_to reasons_exchange_config_path
    assert_equal "Outra cor", reason.reload.label
    assert_equal %w[refund], reason.resolutions
    assert config.reload.reason_for("presente_repetido")

    patch exchange_config_path, params: { return_to: "shipping", exchange_config: {
      return_modes: [ "", "agencia", "coleta" ],
      carrier_contract_attributes: { carrier: "correios", active: "1", username: "loja", access_code: "segredo123",
                                     posting_card: "0067", contract_number: "999", administrative_code: "123",
                                     sender_name: "Loja", sender_zip: "01310-100", sender_street: "Av. Paulista",
                                     sender_number: "1000", sender_district: "Bela Vista", sender_city: "São Paulo", sender_state: "SP" }
    } }
    assert_redirected_to shipping_exchange_config_path
    contract = config.reload.carrier_contract
    assert contract.correios_active?
    assert_equal "segredo123", contract.access_code
    assert_equal "01310100", contract.sender_zip
    assert_equal %w[agencia coleta], config.return_modes

    # código de acesso em branco mantém o salvo
    patch exchange_config_path, params: { return_to: "shipping", exchange_config: { carrier_contract_attributes: { access_code: "" } } }
    assert_equal "segredo123", contract.reload.access_code

    patch exchange_config_path, params: { return_to: "email_templates", exchange_config: { approved_email_subject: "Oba", received_whatsapp_body: "Chegou!" } }
    assert_redirected_to email_templates_exchange_config_path
    assert_equal "Chegou!", config.reload.received_whatsapp_body

    patch exchange_config_path, params: { exchange_config: { return_window_days: 0 } }
    assert_response :unprocessable_entity
  end

  test "aprova, informa postagem manual, recebe, anexa comprovante e conclui" do
    request = create_request(@client, items: [ { resolution: "refund", price: 90 } ],
                                      refund_method: "pix", refund_details: { "pix_key" => "maria@pix.com" })
    sign_in @user

    patch exchange_request_path(request), params: { status: "approved" }
    assert request.reload.approved?

    post return_label_exchange_request_path(request), params: { manual: "1", authorization_code: "AUT123", expires_at: "2026-10-30" }
    assert_equal "AUT123", request.reload.return_authorization_code

    patch exchange_request_path(request), params: { status: "received" }
    assert request.reload.received?

    get exchange_request_path(request)
    assert_select "code", "maria@pix.com"

    refund = request.exchange_refunds.sole
    assert_equal "pix", refund.method
    patch exchange_request_exchange_refund_path(request, refund),
          params: { exchange_refund: { status: "done", receipt: fixture_file_upload("photo.png", "image/png") } }
    assert_equal "done", refund.reload.status
    assert refund.receipt.attached?
    assert request.reload.completed?

    get exchange_request_path(request)
    assert_response :success
    assert_select ".event-list li", minimum: 3

    get public_exchange_tracking_path(@client.exchange_config.slug, request.public_code)
    assert_select "a", /Ver comprovante/
  end
end
