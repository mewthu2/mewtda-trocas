import { Controller } from "@hotwired/stimulus"

// Listas editáveis dentro de um formulário (motivos, regras, faixas de CEP):
// adiciona linhas a partir de um <template> e marca _destroy ao remover.
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-nested-row]")
    const destroy = row.querySelector("input[name*='_destroy']")
    if (destroy && row.dataset.newRecord !== "true") {
      destroy.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }
}
