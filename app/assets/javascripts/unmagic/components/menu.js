// <unmagic-menu> — a dropdown of actions, rendered by `menu`.
//
// The markup is a native <details>, so the trigger works before this script
// upgrades it. The element adds what <details> lacks:
//   - closing on an outside press, on Escape, on choosing an item, and before
//     Turbo caches the page (a restored snapshot would otherwise come back open
//     and with none of this wiring)
//   - arrow keys, Home and End between items
//   - focusing the first item when the menu is opened from the keyboard

const ITEMS = "[role=menuitem]:not([disabled]):not([aria-disabled=true])"

class UnmagicMenu extends HTMLElement {
  #openedFromKeyboard = false

  constructor() {
    super()
    // toggle doesn't bubble, so listen on the way down.
    this.addEventListener("toggle", this.#toggled, true)
    this.addEventListener("keydown", this.#keydown)
    this.addEventListener("click", this.#clicked)
  }

  connectedCallback() {
    this.close()
    document.addEventListener("turbo:before-cache", this.#beforeCache)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.#beforeCache)
    this.#unbind()
  }

  get details() {
    return this.querySelector(":scope > details")
  }

  get summary() {
    return this.details?.querySelector(":scope > summary")
  }

  get items() {
    return [...(this.details?.querySelectorAll(ITEMS) ?? [])]
  }

  close({ focus = false } = {}) {
    const details = this.details
    if (!details?.open) return

    details.open = false
    if (focus) this.summary?.focus()
  }

  #toggled = (event) => {
    if (event.target !== this.details) return

    if (this.details.open) {
      document.addEventListener("pointerdown", this.#outside, true)
      document.addEventListener("keydown", this.#escape)
      if (this.#openedFromKeyboard) this.items[0]?.focus()
    } else {
      this.#unbind()
    }
    this.#openedFromKeyboard = false
  }

  #keydown = (event) => {
    const details = this.details
    if (!details) return

    if (event.target === this.summary && !details.open) {
      if (event.key === "Enter" || event.key === " ") this.#openedFromKeyboard = true
      if (event.key === "ArrowDown") {
        event.preventDefault()
        this.#openedFromKeyboard = true
        details.open = true
      }
      return
    }

    if (!details.open) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.#move(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.#move(-1)
        break
      case "Home":
        event.preventDefault()
        this.items[0]?.focus()
        break
      case "End":
        event.preventDefault()
        this.items.at(-1)?.focus()
        break
      case "Tab":
        this.close()
        break
    }
  }

  #move(step) {
    const items = this.items
    if (items.length === 0) return

    const index = items.indexOf(document.activeElement)
    const next = index === -1 ? (step > 0 ? 0 : items.length - 1) : (index + step + items.length) % items.length
    items[next].focus()
  }

  // Close after the click has done its job: closing during the click would hide a
  // button_to's form before the browser submits it.
  #clicked = (event) => {
    if (event.target instanceof Element && event.target.closest(ITEMS)) setTimeout(() => this.close())
  }

  #outside = (event) => {
    if (!this.contains(event.target)) this.close()
  }

  #escape = (event) => {
    if (event.key === "Escape") this.close({ focus: true })
  }

  #beforeCache = () => {
    this.close()
  }

  #unbind() {
    document.removeEventListener("pointerdown", this.#outside, true)
    document.removeEventListener("keydown", this.#escape)
  }
}

customElements.get("unmagic-menu") || customElements.define("unmagic-menu", UnmagicMenu)
