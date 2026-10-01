// <unmagic-navbar> — the bar across the top of an app, rendered by `navbar`.
// Below the breakpoint the links show while the <details> toggle is open, with
// no script. The element adds closing on Escape, on following a link, on an
// outside press, and when the viewport grows past the breakpoint; aria-expanded
// on the toggle; and closing before Turbo caches the page.

class UnmagicNavbar extends HTMLElement {
  constructor() {
    super()
    this.addEventListener("toggle", this.#toggled, true)
    this.addEventListener("click", this.#clicked)
  }

  connectedCallback() {
    this.#sync()
    document.addEventListener("turbo:before-cache", this.#close)
    this.#media = matchMedia(`(min-width: ${this.#breakpoint})`)
    this.#media.addEventListener("change", this.#grew)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.#close)
    this.#media?.removeEventListener("change", this.#grew)
    this.#unbind()
  }

  #media = null

  get details() {
    return this.querySelector(":scope > details")
  }

  get #breakpoint() {
    const header = this.closest(".UnmagicNavbar")
    if (header?.classList.contains("UnmagicNavbar--collapse-sm")) return "40rem"
    if (header?.classList.contains("UnmagicNavbar--collapse-lg")) return "64rem"
    return "48rem"
  }

  #toggled = (event) => {
    if (event.target !== this.details) return
    this.#sync()
    if (this.details.open) {
      document.addEventListener("pointerdown", this.#outside, true)
      document.addEventListener("keydown", this.#escape)
    } else {
      this.#unbind()
    }
  }

  #sync() {
    const details = this.details
    const summary = details?.querySelector(":scope > summary")
    if (!summary) return
    summary.setAttribute("aria-expanded", String(details.open))
  }

  #clicked = (event) => {
    if (event.target instanceof Element && event.target.closest(".UnmagicNavbar__nav a[href]")) setTimeout(() => this.#close())
  }

  #outside = (event) => {
    if (!this.contains(event.target)) this.#close()
  }

  #escape = (event) => {
    if (event.key !== "Escape") return
    this.#close()
    this.details?.querySelector(":scope > summary")?.focus()
  }

  #grew = (event) => {
    if (event.matches) this.#close()
  }

  #close = () => {
    if (this.details?.open) this.details.open = false
  }

  #unbind() {
    document.removeEventListener("pointerdown", this.#outside, true)
    document.removeEventListener("keydown", this.#escape)
  }
}

customElements.get("unmagic-navbar") || customElements.define("unmagic-navbar", UnmagicNavbar)
