import { Controller } from "@hotwired/stimulus"

// Linha de tabela inteira clicável, sem atrapalhar links e seleção de texto.
export default class extends Controller {
  static values = { url: String }

  go(event) {
    if (event.target.closest("a, button, input") || window.getSelection().toString()) return
    window.Turbo.visit(this.urlValue)
  }
}
