import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    requestAnimationFrame(() => this.element.classList.add("is-visible"))
    this.timeout = setTimeout(() => this.close(), 5000)
  }

  close() {
    clearTimeout(this.timeout)
    this.element.classList.remove("is-visible")
    setTimeout(() => this.element.remove(), 250)
  }
}
