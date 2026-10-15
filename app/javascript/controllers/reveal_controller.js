import { Controller } from "@hotwired/stimulus"

// Em telas estreitas, rola o contêiner horizontal até o item atual (aba ativa, dia aberto) ficar visível.
export default class extends Controller {
  static targets = ["current"]

  connect() {
    if (!this.hasCurrentTarget) return
    const box = this.element
    const item = this.currentTarget
    box.scrollLeft = item.offsetLeft - (box.clientWidth - item.offsetWidth) / 2
  }
}
