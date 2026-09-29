import { Controller } from "@hotwired/stimulus"

// Abas dos 4 e-mails + pré-visualização ao vivo do assunto, corpo e imagem.
export default class extends Controller {
  static targets = ["tab", "panel", "subject", "heading", "body", "image"]
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

    const src = this.imagesValue[this.kind]
    this.imageTarget.hidden = !src
    if (src) this.imageTarget.src = src
  }

  fill(text) {
    return text
      .replaceAll("{{customer_name}}", "Maria Silva")
      .replaceAll("{{order_number}}", "#1042")
      .replaceAll("{{coupon_code}}", this.couponValue)
  }
}
