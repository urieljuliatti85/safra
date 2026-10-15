import { Controller } from "@hotwired/stimulus"

// Copia o texto do alvo para a área de transferência (texto do pedido para o WhatsApp).
export default class extends Controller {
  static targets = ["source", "button", "label"]

  async copy() {
    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    try {
      await navigator.clipboard.writeText(text)
      this.labelTarget.textContent = "Copiado"
    } catch {
      this.sourceTarget.select?.()
      this.labelTarget.textContent = "Selecione e copie"
    }
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.labelTarget.textContent = "Copiar para o WhatsApp" }, 2000)
  }
}
