import { Controller } from "@hotwired/stimulus"

// Envia o formulário assim que o valor muda (ex.: escolher o cliente no select abre o pedido dele).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
