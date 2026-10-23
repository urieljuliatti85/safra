import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Tour guiado: destaca um elemento por passo e atravessa as telas com o Turbo.
// O passo atual fica no sessionStorage, para o tour continuar depois de cada navegação.
const KEY = "safra-tour-step"

export default class extends Controller {
  static values = { steps: Array, autostart: Boolean, seenUrl: String }

  connect() {
    this.reposition = () => requestAnimationFrame(() => this.place())
    this.onKey = (event) => { if (event.key === "Escape") this.finish() }
    const index = this.storedIndex()
    if (index !== null && this.stepsValue[index]) this.render(index)
    else if (this.autostartValue) this.firstVisit()
  }

  // Primeiro acesso: avisa o servidor que o tour já abriu e começa do passo 1.
  firstVisit() {
    this.autostartValue = false
    const token = document.querySelector("meta[name=csrf-token]")?.content
    fetch(this.seenUrlValue, { method: "POST", headers: { "X-CSRF-Token": token, Accept: "application/json" } }).catch(() => {})
    this.go(0)
  }

  disconnect() {
    this.clear()
  }

  start(event) {
    event?.preventDefault()
    this.element.querySelector("details.user-menu")?.removeAttribute("open")
    this.go(0)
  }

  go(index) {
    const step = this.stepsValue[index]
    if (!step) return this.finish()

    this.store(index)
    if (this.onPage(step)) this.render(index)
    else Turbo.visit(step.path)
  }

  finish() {
    this.store(null)
    this.clear()
  }

  render(index) {
    this.clear()
    this.index = index
    const step = this.stepsValue[index]
    const lost = !this.onPage(step)
    // O mesmo passo pode ter uma versão para celular e outra para o computador: destaca a que está visível.
    this.anchor = lost ? null : [ ...document.querySelectorAll(step.target) ].find((el) => el.getClientRects().length) ?? null
    this.anchor?.scrollIntoView({ block: "center", behavior: "instant" })

    this.spot = this.build("div", "tour-spot")
    this.card = this.build("div", "tour-card")
    this.card.setAttribute("role", "dialog")
    this.card.setAttribute("aria-labelledby", "tour-title")
    this.card.innerHTML = `
      <p class="tour-count num"></p>
      <h2 id="tour-title" class="tour-title"></h2>
      <p class="tour-text"></p>
      <div class="tour-actions">
        <button type="button" class="btn" data-tour-action="close">Sair</button>
        <span class="tour-nav">
          <button type="button" class="btn" data-tour-action="back">Voltar</button>
          <button type="button" class="btn btn-primary" data-tour-action="next"></button>
        </span>
      </div>`
    const last = index === this.stepsValue.length - 1
    this.card.querySelector(".tour-count").textContent = `Passo ${index + 1} de ${this.stepsValue.length}`
    this.card.querySelector(".tour-title").textContent = lost ? "Tour guiado" : step.title
    this.card.querySelector(".tour-text").textContent = lost ? "Você saiu da tela do tour. Continuar de onde parou?" : step.text
    this.card.querySelector("[data-tour-action='next']").textContent = lost ? "Continuar" : (last ? "Concluir" : "Próximo")
    this.card.querySelector("[data-tour-action='back']").hidden = lost || index === 0
    this.card.addEventListener("click", (event) => {
      const action = event.target.closest("[data-tour-action]")?.dataset.tourAction
      if (action === "close") this.finish()
      if (action === "back") this.go(index - 1)
      if (action === "next") lost ? Turbo.visit(step.path) : this.go(index + 1)
    })

    document.body.append(this.spot, this.card)
    this.place()
    window.addEventListener("resize", this.reposition)
    window.addEventListener("scroll", this.reposition, { passive: true })
    document.addEventListener("keydown", this.onKey)
    this.card.querySelector("[data-tour-action='next']").focus({ preventScroll: true })
  }

  // Sem alvo, o recorte some no centro e a sombra escurece a tela inteira.
  place() {
    if (!this.card) return
    const pad = 6
    const rect = this.anchor?.getBoundingClientRect()
    if (!rect) {
      Object.assign(this.spot.style, { top: "50%", left: "50%", width: "0", height: "0" })
      this.card.classList.add("is-center")
      return
    }

    Object.assign(this.spot.style, {
      top: `${rect.top - pad}px`, left: `${rect.left - pad}px`, width: `${rect.width + pad * 2}px`, height: `${rect.height + pad * 2}px`
    })
    this.card.classList.remove("is-center")
    // No celular o cartão fica embaixo (CSS), ou em cima quando o destaque está na metade de baixo da tela.
    this.card.classList.toggle("is-top", rect.top > window.innerHeight / 2)
    if (window.innerWidth < 640) return Object.assign(this.card.style, { top: "", left: "" })

    const gap = 14
    const card = this.card.getBoundingClientRect()
    const below = rect.bottom + pad + gap
    const top = below + card.height <= window.innerHeight ? below : Math.max(16, rect.top - pad - gap - card.height)
    const left = Math.min(Math.max(16, rect.left), window.innerWidth - card.width - 16)
    Object.assign(this.card.style, { top: `${top}px`, left: `${left}px` })
  }

  clear() {
    this.spot?.remove()
    this.card?.remove()
    this.spot = this.card = null
    window.removeEventListener("resize", this.reposition)
    window.removeEventListener("scroll", this.reposition)
    document.removeEventListener("keydown", this.onKey)
  }

  build(tag, className) {
    const element = document.createElement(tag)
    element.className = className
    element.setAttribute("data-turbo-temporary", "") // fora do cache do Turbo
    return element
  }

  onPage(step) {
    return new URL(step.path, window.location.origin).pathname === window.location.pathname
  }

  storedIndex() {
    try {
      const value = sessionStorage.getItem(KEY)
      return value === null ? null : Number(value)
    } catch {
      return null
    }
  }

  store(index) {
    try {
      if (index === null) sessionStorage.removeItem(KEY)
      else sessionStorage.setItem(KEY, String(index))
    } catch {
      // Sem sessionStorage o tour só não continua entre telas.
    }
  }
}
