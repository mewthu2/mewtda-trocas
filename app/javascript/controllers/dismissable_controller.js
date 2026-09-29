import { Controller } from "@hotwired/stimulus"

// Fecha um <details> (menu) ao clicar fora dele.
export default class extends Controller {
  connect() {
    this.onClick = (event) => {
      if (!this.element.contains(event.target)) this.element.open = false
    }
    document.addEventListener("click", this.onClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
  }
}
