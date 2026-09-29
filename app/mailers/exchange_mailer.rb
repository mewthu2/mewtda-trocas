# E-mail de etapa da solicitação, com o HTML já montado por ExchangeEmailRenderer.
class ExchangeMailer < ApplicationMailer
  layout false

  def notification(to:, from:, subject:, html:, reply_to: nil)
    mail(to: to, from: from, reply_to: reply_to, subject: subject) do |format|
      format.html { render html: html.html_safe }
    end
  end
end
