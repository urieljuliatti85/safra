import { Controller } from "@hotwired/stimulus"

// Copia o texto do alvo para a área de transferência (texto do pedido para o WhatsApp).
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    try {
      await navigator.clipboard.writeText(text)
      this.buttonTarget.textContent = "Copiado"
    } catch {
      this.sourceTarget.select?.()
      this.buttonTarget.textContent = "Selecione e copie"
    }
    setTimeout(() => { this.buttonTarget.textContent = "Copiar para o WhatsApp" }, 2000)
  }
}
