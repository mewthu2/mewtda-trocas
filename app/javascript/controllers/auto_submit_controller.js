import { Controller } from "@hotwired/stimulus"

// Envia o formulário ao mudar um campo (seletor de loja, busca).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }

  debounced() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), 350)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
