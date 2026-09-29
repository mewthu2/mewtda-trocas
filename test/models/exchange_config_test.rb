require "test_helper"

class ExchangeConfigTest < ActiveSupport::TestCase
  test "gera slug a partir do nome do cliente e desempata com o id" do
    first = create_config(create_client(name: "Loja Bonita"))
    other_client = create_client(name: "Loja  Bonita")
    second = create_config(other_client)

    assert_equal "loja-bonita", first.slug
    assert_equal "loja-bonita-#{other_client.id}", second.slug
  end

  test "preenche os textos padrão dos e-mails" do
    config = create_config(create_client)

    assert_equal ExchangeConfig::DEFAULT_EMAIL_CONTENT[:approved][:subject], config.approved_email_subject
    assert_includes config.approved_email_body, "{{coupon_code}}"
  end

  test "exige nome da empresa quando ativo" do
    config = create_client.build_exchange_config(active: true, company_name: "")

    assert_not config.valid?
    assert config.errors.key?(:company_name)
  end
end
