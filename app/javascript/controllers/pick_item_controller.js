import { Controller } from "@hotwired/stimulus"

// Item do pedido na página pública: mostra as opções ao selecionar e exige
// foto quando o motivo é defeito/avaria.
export default class extends Controller {
  static targets = ["toggle", "options", "reason", "photo", "photoInput", "photoLabel"]
  static values = { defect: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.toggleTarget.checked
    this.element.classList.toggle("is-selected", selected)
    this.optionsTarget.hidden = !selected
    this.reasonTarget.required = selected
    this.reasonChanged()
  }

  reasonChanged() {
    const needsPhoto = this.toggleTarget.checked && this.reasonTarget.value === this.defectValue
    this.photoTarget.hidden = !needsPhoto
    this.photoInputTarget.required = needsPhoto
  }

  photoChosen() {
    const file = this.photoInputTarget.files[0]
    this.photoLabelTarget.textContent = file ? file.name : "Enviar foto do defeito"
  }
}
