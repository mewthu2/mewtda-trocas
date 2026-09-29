import { Controller } from "@hotwired/stimulus"

// Item do pedido na página pública: ao marcar, mostra o motivo; o motivo
// escolhido abre só o painel dele (resultados, perguntas, foto, condições).
// Campos dos painéis escondidos ficam desabilitados para não serem enviados.
export default class extends Controller {
  static targets = ["toggle", "options", "reason", "panel", "photoLabel"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasOptionsTarget) return
    const selected = this.toggleTarget.checked
    this.element.classList.toggle("is-selected", selected)
    this.optionsTarget.hidden = !selected
    this.reasonTarget.required = selected
    this.reasonChanged()
  }

  reasonChanged() {
    const active = this.toggleTarget.checked ? this.reasonTarget.value : null
    this.panelTargets.forEach((panel) => {
      const show = panel.dataset.reason === active
      panel.hidden = !show
      panel.querySelectorAll("input, select, textarea").forEach((field) => (field.disabled = !show))
    })
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  photoChosen(event) {
    const file = event.target.files[0]
    const label = event.target.closest("label").querySelector("[data-pick-item-target=photoLabel]")
    if (label) label.textContent = file ? file.name : "Enviar foto"
  }
}
