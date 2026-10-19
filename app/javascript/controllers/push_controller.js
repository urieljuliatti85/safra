import { Controller } from "@hotwired/stimulus"

// Avisos de produção neste aparelho: pede permissão, inscreve no serviço de push do navegador e guarda no servidor
// os setores que a pessoa acompanha. O servidor só manda aviso do que mudou nesses setores.
export default class extends Controller {
  static targets = ["status", "sectors", "enable", "save", "disable", "form"]
  static values = { key: String, url: String }

  async connect() {
    if (!("serviceWorker" in navigator && "PushManager" in window && "Notification" in window)) {
      return this.show("unsupported")
    }
    await this.refresh()
  }

  async refresh() {
    if (Notification.permission === "denied") return this.show("blocked")

    const subscription = await this.subscription()
    if (!subscription) return this.show("off")

    const response = await fetch(`${this.urlValue}?endpoint=${encodeURIComponent(subscription.endpoint)}`, { headers: { Accept: "application/json" } })
    if (!response.ok) return this.show("off")

    this.check((await response.json()).sectors)
    this.show("on")
  }

  async enable() {
    if (await Notification.requestPermission() !== "granted") return this.show("blocked")

    const registration = await this.registration()
    const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: this.decode(this.keyValue) })
    await this.store(subscription)
  }

  async save() {
    const subscription = await this.subscription()
    if (subscription) await this.store(subscription)
  }

  async disable() {
    const subscription = await this.subscription()
    if (subscription) {
      await fetch(`${this.urlValue}?endpoint=${encodeURIComponent(subscription.endpoint)}`, { method: "DELETE", headers: this.headers })
      await subscription.unsubscribe()
    }
    this.show("off")
  }

  async store(subscription) {
    const { endpoint, keys } = subscription.toJSON()
    const sectors = this.sectorsTargets.filter((box) => box.checked).map((box) => box.value)
    const response = await fetch(this.urlValue, { method: "POST", headers: this.headers, body: JSON.stringify({ endpoint, keys, sectors }) })
    if (response.ok) {
      this.show("on", "Avisos ativados neste aparelho.")
    } else {
      const { error } = await response.json()
      await this.refresh()
      this.statusTarget.textContent = error
    }
  }

  async registration() {
    await navigator.serviceWorker.register("/service-worker.js")
    return navigator.serviceWorker.ready
  }

  async subscription() {
    return (await this.registration()).pushManager.getSubscription()
  }

  check(sectors) {
    this.sectorsTargets.forEach((box) => { box.checked = sectors.includes(box.value) })
  }

  // off: ainda não ativou · on: ativado · blocked: permissão negada no navegador · unsupported: aparelho sem suporte
  show(state, message = null) {
    this.element.dataset.state = state
    this.enableTarget.hidden = state !== "off"
    this.formTarget.hidden = state === "unsupported" || state === "blocked"
    this.saveTarget.hidden = state !== "on"
    this.disableTarget.hidden = state !== "on"
    this.statusTarget.textContent = message || {
      off: "Os avisos estão desligados neste aparelho.",
      on: "Avisos ativados neste aparelho.",
      blocked: "O navegador bloqueou os avisos. Libere nas configurações do site e volte aqui.",
      unsupported: "Este aparelho não recebe avisos. No iPhone, use Compartilhar > Adicionar à Tela de Início e abra o Safra por lá."
    }[state]
  }

  get headers() {
    return { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content }
  }

  decode(base64) {
    const padded = (base64 + "=".repeat((4 - (base64.length % 4)) % 4)).replace(/-/g, "+").replace(/_/g, "/")
    return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0))
  }
}
