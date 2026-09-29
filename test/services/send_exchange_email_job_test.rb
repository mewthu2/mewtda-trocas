require "test_helper"

class SendExchangeEmailJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "sem domínio próprio usa o domínio padrão do Mailer To Go com o nome da loja" do
    client = create_client
    create_config(client, support_email: "sac@loja.com")
    request = create_request(client, status: :approved, public_code: "PROTO123")

    with_env("MAILERTOGO_DOMAIN" => "mewtda.com.br") do
      assert_emails(1) { SendExchangeEmailJob.perform_now(exchange_request_id: request.id, kind: "approved") }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "trocas@mewtda.com.br" ], mail.from
    assert_equal "Loja Teste", mail[:from].display_names.first
    assert_equal [ "sac@loja.com" ], mail.reply_to
    assert_equal [ "maria@example.com" ], mail.to
    assert_equal "Sua solicitação foi aprovada!", mail.subject
    assert_includes mail.html_part ? mail.html_part.body.to_s : mail.body.to_s, "PROTO123"
  end

  test "domínio próprio verificado vira o remetente" do
    client = create_client(email_sending_domain: "loja.com", email_domain_status: "verified", email_from_local: "ola")
    create_config(client)
    request = create_request(client)

    with_env("MAILERTOGO_DOMAIN" => "mewtda.com.br") do
      SendExchangeEmailJob.perform_now(exchange_request_id: request.id, kind: "requested")
    end

    assert_equal [ "ola@loja.com" ], ActionMailer::Base.deliveries.last.from
  end

  test "sem nenhum domínio de envio não manda nada" do
    client = create_client(email_sending_domain: "loja.com", email_domain_status: "pending")
    create_config(client)
    request = create_request(client)

    with_env("MAILERTOGO_DOMAIN" => nil) do
      assert_no_emails { SendExchangeEmailJob.perform_now(exchange_request_id: request.id, kind: "requested") }
    end
  end

  private

  def with_env(vars)
    previous = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| ENV[k] = v }
  end
end
