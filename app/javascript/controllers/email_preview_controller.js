import { Controller } from "@hotwired/stimulus"

// Abas das mensagens por etapa + pré-visualização ao vivo do assunto, corpo e imagem.
export default class extends Controller {
  static targets = ["tab", "panel", "subject", "heading", "body", "image", "whatsapp"]
  static values = { images: Object, coupon: String }

  connect() {
    this.kind = this.tabTargets[0].dataset.kind
    this.render()
  }

  select(event) {
    this.kind = event.currentTarget.dataset.kind
    this.tabTargets.forEach((tab) => tab.classList.toggle("is-active", tab.dataset.kind === this.kind))
    this.panelTargets.forEach((panel) => (panel.hidden = panel.dataset.kind !== this.kind))
    this.render()
  }

  image(event) {
    const file = event.target.files[0]
    if (!file) return
    this.imagesValue = { ...this.imagesValue, [event.target.dataset.kind]: URL.createObjectURL(file) }
    this.render()
  }

  render() {
    const panel = this.panelTargets.find((p) => p.dataset.kind === this.kind)
    const subject = this.fill(panel.querySelector("[data-role=subject]").value) || "Assunto do e-mail"
    const body = this.fill(panel.querySelector("[data-role=body]").value) || "Texto do e-mail."

    this.subjectTarget.textContent = subject
    this.headingTarget.textContent = subject
    this.bodyTarget.replaceChildren(
      ...body.split(/\n{2,}/).map((paragraph) => {
        const p = document.createElement("p")
        paragraph.split("\n").forEach((line, i) => {
          if (i) p.appendChild(document.createElement("br"))
          p.appendChild(document.createTextNode(line))
        })
        return p
      })
    )

    const whatsapp = panel.querySelector("[data-role=whatsapp]")
    if (this.hasWhatsappTarget) this.whatsappTarget.textContent = whatsapp ? this.fill(whatsapp.value) : ""

    const src = this.imagesValue[this.kind]
    this.imageTarget.hidden = !src
    if (src) this.imageTarget.src = src
  }

  fill(text) {
    const sample = {
      customer_name: "Maria Silva", order_number: "#1042", request_code: "K7Q2M9XA", coupon_code: this.couponValue,
      credit_amount: "R$ 189,90", return_code: "1234567890", return_expires_at: "15/10/2026", refund_amount: "R$ 189,90",
      invoice_url: "https://loja.com/fatura", rejection_reason: "Produto com sinais de uso.",
      tracking_url: "https://trocas.mewtda.com/troca/loja/acompanhar/K7Q2M9XA", analysis_sla_days: "2", refund_sla_days: "7"
    }
    return text.replace(/\{\{\s*(\w+)\s*\}\}/g, (match, name) => sample[name] ?? match)
  }
}
