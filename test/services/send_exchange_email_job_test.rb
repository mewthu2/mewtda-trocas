require "test_helper"

class SendExchangeEmailJobTest < ActiveSupport::TestCase
  test "interpola variáveis e envia via SES quando o domínio está verificado" do
    client = create_client(email_sending_domain: "loja.com", ses_verification_status: "verified")
    create_config(client)
    request = create_request(client, status: :approved)
    request.update!(coupon_code: "RECXYZ")

    fake_ses = Object.new
    def fake_ses.send_email(**args) = (@sent = args)
    def fake_ses.sent = @sent

    original = Ses::SendEmailService.instance_method(:ses)
    Ses::SendEmailService.define_method(:ses) { fake_ses }
    SendExchangeEmailJob.perform_now(exchange_request_id: request.id, kind: "approved")
  ensure
    Ses::SendEmailService.define_method(:ses, original)

    assert_equal "naoresponda@loja.com", fake_ses.sent[:from_email_address]
    html = fake_ses.sent.dig(:content, :simple, :body, :html, :data)
    assert_includes html, "RECXYZ"
    assert_includes html, "Maria"
  end
end
