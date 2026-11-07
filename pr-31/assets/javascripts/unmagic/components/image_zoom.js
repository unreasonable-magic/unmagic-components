// <unmagic-image-zoom> — image inspection rendered by `image_zoom`.
// Native dialog supplies focus trapping and Escape. Adds backdrop dismissal,
// open()/close(), and bubbling unmagic-image-zoom:change with { open }.
class UnmagicImageZoom extends HTMLElement {
  constructor() {
    super()
    this.addEventListener("click", (event) => {
      if (event.target.closest(".UnmagicImageZoom__trigger")) this.open()
      else if (event.target === this.#dialog || event.target.closest("[data-image-close]")) this.close()
    })
    this.addEventListener("close", () => this.#changed(false), true)
  }
  get #dialog() { return this.querySelector("dialog") }
  connectedCallback() { document.addEventListener("turbo:before-cache", this.close) }
  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.close)
    this.close()
  }
  open() {
    if (this.#dialog.open) return
    this.#dialog.showModal()
    this.#changed(true)
  }
  close = () => { this.#dialog?.close() }
  #changed(open) {
    this.dispatchEvent(new CustomEvent("unmagic-image-zoom:change", { bubbles: true, detail: { open } }))
  }
}
customElements.get("unmagic-image-zoom") || customElements.define("unmagic-image-zoom", UnmagicImageZoom)
