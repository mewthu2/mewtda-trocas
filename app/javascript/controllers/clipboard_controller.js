import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const button = event.currentTarget
    await navigator.clipboard.writeText(this.textValue)
    const icon = button.querySelector(".msr")
    const previous = icon.textContent
    icon.textContent = "check"
    setTimeout(() => (icon.textContent = previous), 1500)
  }
}
