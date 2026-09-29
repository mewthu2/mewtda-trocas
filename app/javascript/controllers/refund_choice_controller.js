import { Controller } from "@hotwired/stimulus"

// Página pública: mostra "como receber o dinheiro" só quando algum item
// selecionado escolheu devolução, e os campos da forma escolhida (Pix ou
// transferência). Campos escondidos ficam desabilitados.
export default class extends Controller {
  static targets = ["box", "fields"]

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasBoxTarget) return
    const wantsRefund = [...this.element.querySelectorAll("input[type=radio][name$='[resolution]']:checked")]
      .some((radio) => !radio.disabled && radio.value === "refund")
    this.boxTarget.hidden = !wantsRefund

    const method = this.element.querySelector("input[name=refund_method]:checked")?.value
    this.boxTarget.querySelectorAll("input[name=refund_method]").forEach((radio) => (radio.disabled = !wantsRefund))
    this.fieldsTargets.forEach((group) => {
      const show = wantsRefund && group.dataset.method === method
      group.hidden = !show
      group.querySelectorAll("input").forEach((field) => (field.disabled = !show))
    })
  }
}
