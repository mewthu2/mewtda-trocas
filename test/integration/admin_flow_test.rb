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

  test "salva configuração e templates" do
    sign_in @user

    get edit_exchange_config_path
    assert_response :success
    get email_templates_exchange_config_path
    assert_response :success

    patch exchange_config_path, params: { exchange_config: { company_name: "Nova", return_window_days: 10, accent_color: "#00aa00" } }
    assert_redirected_to edit_exchange_config_path
    assert_equal 10, @client.exchange_config.reload.return_window_days

    patch exchange_config_path, params: { return_to: "email_templates", exchange_config: { approved_email_subject: "Oba" } }
    assert_redirected_to email_templates_exchange_config_path

    patch exchange_config_path, params: { exchange_config: { return_window_days: 0 } }
    assert_response :unprocessable_entity
  end
end
