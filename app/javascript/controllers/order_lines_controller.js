import { Controller } from "@hotwired/stimulus"

// "Adicionar linha" na grade de pedidos: inclui o produto escolhido na grade sem recarregar a página, para dar para
// adicionar vários produtos, preencher e salvar uma vez só (uma versão só). O que já foi digitado fica.
// A linha nova sai dos modelos <template> da própria grade; produto já na grade só recebe o foco.
export default class extends Controller {
  static targets = ["select", "rowTemplate", "groupTemplate", "empty"]

  add(event) {
    event.preventDefault()
    const option = this.selectTarget.selectedOptions[0]
    if (!option || option.disabled) return

    const key = `${option.value}|${option.dataset.unit}`
    const existing = this.row(key)
    if (existing) {
      this.dispatch("added", { target: existing }) // no celular, "Só com pedido" escondia a linha sem quantidade no dia
      this.focus(existing)
      return
    }

    const html = this.rowTemplateTarget.innerHTML
      .replaceAll("__KEY__", this.escape(key))
      .replaceAll("__NAME__", this.escape(option.dataset.name))
      .replaceAll("__UNIT__", this.escape(option.dataset.unit))
      .replaceAll("__MEASURE__", this.escape(option.dataset.measure))
    const holder = document.createElement("template") // <template> aceita <tr> solto; um fragmento comum descartaria
    holder.innerHTML = html.trim()
    const row = holder.content.firstElementChild

    const body = this.groupBody(option.dataset.group)
    const after = [...body.querySelectorAll("tr[data-order-lines-name]")]
      .find((other) => other.dataset.orderLinesName.localeCompare(option.dataset.name, "pt-BR") > 0)
    body.insertBefore(row, after || null)
    if (this.hasEmptyTarget) this.emptyTarget.remove()

    option.disabled = true
    this.selectNextEnabled()
    this.dispatch("added", { target: row })
    this.focus(row)
  }

  // Só a linha nova, ainda não salva, pode ser tirada da grade; o produto volta para a lista.
  remove(event) {
    const row = event.currentTarget.closest("tr")
    const productId = row.dataset.orderLinesKey.split("|")[0]
    const option = [...this.selectTarget.options].find((opt) => opt.value === productId)
    if (option) option.disabled = false
    const body = row.parentElement
    row.remove()
    if (!body.querySelector("tr[data-order-lines-key]")) body.remove()
    this.dispatch("removed", { target: this.element.querySelector("form") })
  }

  row(key) {
    return [...this.element.querySelectorAll("tr[data-order-lines-key]")].find((row) => row.dataset.orderLinesKey === key)
  }

  // O grupo do produto (Processados, In natura, Frutas), criado na ordem da grade quando ainda não existe.
  groupBody(group) {
    const table = this.element.querySelector("table.order-sheet")
    const existing = table.querySelector(`tbody[data-order-lines-group="${group}"]`)
    if (existing) return existing

    const template = this.groupTemplateTargets.find((t) => t.dataset.group === group)
    const body = template.content.firstElementChild.cloneNode(true)
    const order = this.groupTemplateTargets.map((t) => t.dataset.group)
    const next = [...table.querySelectorAll("tbody[data-order-lines-group]")]
      .find((other) => order.indexOf(other.dataset.orderLinesGroup) > order.indexOf(group))
    table.insertBefore(body, next || null)
    return body
  }

  selectNextEnabled() {
    const next = [...this.selectTarget.options].find((opt) => !opt.disabled)
    if (next) this.selectTarget.value = next.value
  }

  // A primeira célula visível (no celular, a do dia aberto).
  focus(row) {
    row.scrollIntoView({ block: "center", behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" })
    const input = [...row.querySelectorAll("td input")].find((el) => el.offsetParent !== null)
    input?.focus({ preventScroll: true })
  }

  escape(text) {
    const span = document.createElement("span")
    span.textContent = text ?? ""
    return span.innerHTML.replaceAll('"', "&quot;")
  }
}
