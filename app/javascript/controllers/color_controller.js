import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label"]

  sync() {
    this.labelTarget.textContent = this.inputTarget.value
  }
}
