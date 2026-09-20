// <unmagic-toolbar role="toolbar"> — a row of controls with one Tab stop,
// rendered by `ai_chat_action_bar`.
//
// The WAI-ARIA toolbar pattern: Tab enters and leaves the row as one stop, and
// Left, Right, Home and End move between its controls (a roving tabindex). The
// control that last had focus is the one Tab returns to. Controls are its
// buttons, links and anything already carrying a tabindex, skipping disabled and
// hidden ones. It rescans when its contents change, so a streamed or
// re-rendered bar needs no setup.

class UnmagicToolbar extends HTMLElement {
  #observer = new MutationObserver(() => this.#reset())

  constructor() {
    super()
    this.addEventListener("keydown", this.#keydown)
    this.addEventListener("focusin", (event) => {
      if (this.#controls.includes(event.target)) this.#activate(event.target)
    })
  }

  connectedCallback() {
    this.#reset()
    this.#observer.observe(this, { childList: true, subtree: true })
  }

  disconnectedCallback() {
    this.#observer.disconnect()
  }

  get #controls() {
    return Array.from(this.querySelectorAll("button, a[href], [tabindex]")).filter(
      (control) => !control.disabled && control.getAttribute("aria-disabled") !== "true" && !control.closest("[hidden]"),
    )
  }

  #reset() {
    const controls = this.#controls
    const current = controls.find((control) => control.getAttribute("tabindex") === "0") ?? controls[0]
    if (current) this.#activate(current, controls)
  }

  #activate(target, controls = this.#controls) {
    for (const control of controls) control.setAttribute("tabindex", control === target ? "0" : "-1")
  }

  #keydown = (event) => {
    const controls = this.#controls
    const index = controls.indexOf(document.activeElement)
    if (index === -1) return

    let next
    switch (event.key) {
      case "ArrowRight":
        next = controls[(index + 1) % controls.length]
        break
      case "ArrowLeft":
        next = controls[(index - 1 + controls.length) % controls.length]
        break
      case "Home":
        next = controls[0]
        break
      case "End":
        next = controls[controls.length - 1]
        break
      default:
        return
    }

    event.preventDefault()
    this.#activate(next, controls)
    next.focus()
  }
}

customElements.get("unmagic-toolbar") || customElements.define("unmagic-toolbar", UnmagicToolbar)
