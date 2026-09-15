// <unmagic-tooltip text="…"> — a hint shown on hover or focus, rendered by
// `tooltip`.
//
// The hint is a manual popover, so it renders in the top layer and no ancestor's
// overflow can clip it. It is placed with fixed, viewport coordinates each time it
// opens: on the preferred side (placement="top" or "bottom"), flipped when there
// isn't room, and clamped so it never runs off the sides.
//
// If the content has its own focusable element (a button, a link) the hint
// describes that element; otherwise the element itself becomes focusable, so a
// keyboard user can reach the explanation. Escape dismisses it.

const GAP = 8
const MARGIN = 8
const DELAY = 150
const FOCUSABLE = "a[href], button, input, select, textarea, [tabindex]:not([tabindex='-1'])"

let sequence = 0

class UnmagicTooltip extends HTMLElement {
  static observedAttributes = ["text"]

  #popup = null
  #pending = null
  #open = false

  constructor() {
    super()
    // On the element itself, once, so moving it (a Turbo cache restore, a permanent
    // element) never doubles them up.
    this.addEventListener("pointerenter", () => this.#schedule())
    this.addEventListener("pointerleave", () => this.#hide())
    this.addEventListener("focusin", () => this.#schedule(0))
    this.addEventListener("focusout", () => this.#hide())
  }

  connectedCallback() {
    if (this.#popup) return

    // A snapshot Turbo restores is a clone that already holds a popup, but not
    // this instance's wiring. Start again from the content.
    this.querySelectorAll(":scope > .UnmagicTooltip__popup").forEach((popup) => popup.remove())

    this.#popup = document.createElement("span")
    this.#popup.className = "UnmagicTooltip__popup"
    this.#popup.id = `unmagic_tooltip_${++sequence}`
    this.#popup.setAttribute("role", "tooltip")
    this.#popup.setAttribute("popover", "manual")
    this.#popup.textContent = this.getAttribute("text") ?? ""
    this.append(this.#popup)

    const trigger = this.querySelector(FOCUSABLE)
    if (trigger) {
      trigger.setAttribute("aria-describedby", this.#popup.id)
    } else {
      this.tabIndex = 0
      this.setAttribute("aria-describedby", this.#popup.id)
    }
  }

  disconnectedCallback() {
    this.#hide()
  }

  attributeChangedCallback(_name, _old, text) {
    if (this.#popup) this.#popup.textContent = text ?? ""
  }

  #schedule(delay = DELAY) {
    clearTimeout(this.#pending)
    this.#pending = setTimeout(() => this.#show(), delay)
  }

  #show() {
    const popup = this.#popup
    if (this.#open || !popup?.showPopover || !popup.textContent) return

    this.#open = true
    popup.showPopover()
    this.#position()
    popup.setAttribute("data-open", "")

    window.addEventListener("scroll", this.#reposition, { passive: true, capture: true })
    window.addEventListener("resize", this.#reposition, { passive: true })
    document.addEventListener("keydown", this.#escape)
  }

  #hide() {
    clearTimeout(this.#pending)
    if (!this.#open) return

    this.#open = false
    this.#popup.removeAttribute("data-open")
    this.#popup.hidePopover()

    window.removeEventListener("scroll", this.#reposition, { capture: true })
    window.removeEventListener("resize", this.#reposition)
    document.removeEventListener("keydown", this.#escape)
  }

  #escape = (event) => {
    if (event.key === "Escape") this.#hide()
  }

  #reposition = () => {
    if (this.#open) this.#position()
  }

  #position() {
    const anchor = this.getBoundingClientRect()
    const popup = this.#popup.getBoundingClientRect()
    const viewportWidth = document.documentElement.clientWidth
    const viewportHeight = document.documentElement.clientHeight

    const above = anchor.top - popup.height - GAP
    const below = anchor.bottom + GAP
    const fitsAbove = above >= MARGIN
    const fitsBelow = below + popup.height <= viewportHeight - MARGIN

    const top = this.getAttribute("placement") === "bottom"
      ? (fitsBelow || !fitsAbove ? below : above)
      : (fitsAbove || !fitsBelow ? above : below)

    const centred = anchor.left + anchor.width / 2 - popup.width / 2
    const left = Math.max(MARGIN, Math.min(centred, viewportWidth - popup.width - MARGIN))

    this.#popup.style.top = `${top}px`
    this.#popup.style.left = `${left}px`
    this.#popup.dataset.side = top === above ? "top" : "bottom"
  }
}

customElements.get("unmagic-tooltip") || customElements.define("unmagic-tooltip", UnmagicTooltip)
