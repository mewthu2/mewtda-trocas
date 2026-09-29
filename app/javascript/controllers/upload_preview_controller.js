import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]

  show(event) {
    const file = event.target.files[0]
    if (!file) return
    const img = document.createElement("img")
    img.src = URL.createObjectURL(file)
    img.alt = ""
    this.previewTarget.replaceChildren(img)
  }
}
