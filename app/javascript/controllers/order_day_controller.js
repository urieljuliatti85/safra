import { Controller } from "@hotwired/stimulus"

// Grade de pedidos no celular: um dia de entrega por vez e, com "Só com pedido", só os produtos com quantidade nesse dia.
// Só troca classes; as regras que escondem valem apenas no celular, então no computador a grade continua inteira.
export default class extends Controller {
  static targets = ["day", "count", "filter", "group", "row", "empty"]
  static values = { index: Number, onlyFilled: Boolean }

  connect() {
    const saved = this.restore()
    if (saved && saved.index < this.dayTargets.length) {
      this.indexValue = saved.index
      this.onlyFilledValue = saved.onlyFilled
    }
    this.render()
  }

  pick({ params: { index } }) {
    this.indexValue = index
    this.render()
  }

  showAll() {
    this.onlyFilledValue = false
    this.render()
  }

  showFilled() {
    this.onlyFilledValue = true
    this.render()
  }

  // Ao digitar só atualiza a contagem de cada dia; a linha não some enquanto a pessoa apaga o número.
  count() {
    this.countTargets.forEach((target, index) => {
      const filled = this.rowTargets.filter((row) => this.filled(row, index)).length
      target.textContent = filled ? `${filled} ${filled === 1 ? "item" : "itens"}` : "-"
    })
  }

  render() {
    const day = this.indexValue
    this.element.querySelectorAll("[data-col]").forEach((cell) => cell.classList.toggle("off-day", Number(cell.dataset.col) !== day))
    this.dayTargets.forEach((button, index) => button.setAttribute("aria-pressed", index === day))
    this.filterTargets.forEach((button, index) => button.setAttribute("aria-pressed", index === (this.onlyFilledValue ? 1 : 0)))

    let visible = 0
    this.rowTargets.forEach((row) => {
      const show = !this.onlyFilledValue || this.filled(row, day)
      row.classList.toggle("off-filter", !show)
      if (show) visible++
    })
    this.groupTargets.forEach((group) => group.classList.toggle("off-filter", !group.querySelector("tr[data-order-day-target='row']:not(.off-filter)")))
    // O aviso é do filtro: semana sem nenhuma linha já tem o aviso da grade, e "Todos" não teria o que mostrar.
    const filteredOut = this.onlyFilledValue && this.rowTargets.length > 0 && visible === 0
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("off-filter", !filteredOut)
    this.count()
    this.remember()
  }

  // Depois de salvar a página recarrega: volta no mesmo dia e filtro (por cliente e semana, só nesta aba).
  get storageKey() {
    const params = new URLSearchParams(location.search)
    params.sort() // o select de cliente e o redirect depois de salvar montam a mesma URL em ordens diferentes
    return `order-day:${location.pathname}?${params}`
  }

  remember() {
    try {
      sessionStorage.setItem(this.storageKey, JSON.stringify({ index: this.indexValue, onlyFilled: this.onlyFilledValue }))
    } catch {}
  }

  restore() {
    try {
      return JSON.parse(sessionStorage.getItem(this.storageKey))
    } catch {
      return null
    }
  }

  filled(row, index) {
    return (row.querySelector(`[data-col="${index}"] input`)?.value ?? "").trim() !== ""
  }
}
