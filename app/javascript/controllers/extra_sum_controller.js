import { Controller } from "@hotwired/stimulus"

// Grade do extra (R1.37, D23): enquanto se digita o acréscimo, a célula mostra atual + acréscimo = total.
// A quantidade atual vem em data-current (ponto decimal); o digitado usa vírgula. Texto que não é número não mostra nada:
// o salvamento é que recusa e explica.
export default class extends Controller {
  update(event) {
    const input = event.target
    if (!input.classList?.contains("cell-extra")) return
    const sum = input.parentElement.querySelector(".extra-sum")
    if (!sum) return

    const typed = input.value.trim().replace(",", ".")
    if (!/^\d+(\.\d{1,3})?$/.test(typed) || Number(typed) === 0) {
      sum.textContent = ""
      return
    }
    const current = Number(input.dataset.current || 0)
    const total = current + Number(typed)
    sum.textContent = current ? `${this.format(current)} + ${this.format(typed)} = ${this.format(total)}` : `= ${this.format(total)}`
  }

  format(value) {
    return Number(value).toLocaleString("pt-BR", { maximumFractionDigits: 3 })
  }
}
