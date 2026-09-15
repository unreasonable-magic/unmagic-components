// <unmagic-tabs> — tabs that switch panels in the page, rendered by `tabs`.
//
// The server renders the whole ARIA tab pattern (roles, aria-controls, the
// selected tab and the hidden panels), so the element only moves the selection:
// on a click, or with the arrow keys, Home and End, which also move focus. Only the
// selected tab is in the tab order.
//
// When the element has an id, the chosen tab is remembered in sessionStorage for
// that page, and re-applied after a morph refresh (which resets the markup to the
// server's selection). Each change fires unmagic-tabs:change.

class UnmagicTabs extends HTMLElement {
  constructor() {
    super()
    this.addEventListener("click", this.#clicked)
    this.addEventListener("keydown", this.#keydown)
  }

  connectedCallback() {
    this.#restore()
    document.addEventListener("turbo:morph", this.#restore)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:morph", this.#restore)
  }

  get tabs() {
    return [...this.querySelectorAll(":scope > [role=tablist] > [role=tab]")]
  }

  select(tab, { focus = false, remember = true } = {}) {
    for (const each of this.tabs) {
      const selected = each === tab
      each.setAttribute("aria-selected", String(selected))
      each.tabIndex = selected ? 0 : -1

      const panel = document.getElementById(each.getAttribute("aria-controls"))
      if (panel) panel.hidden = !selected
    }

    if (focus) tab.focus()
    if (!remember) return

    const key = this.#storageKey
    if (key) {
      try {
        sessionStorage.setItem(key, tab.id)
      } catch {
        // Storage can be unavailable (a private window, blocked site data); the
        // selection just isn't remembered.
      }
    }
    this.dispatchEvent(new CustomEvent("unmagic-tabs:change", { bubbles: true, detail: { tab } }))
  }

  #clicked = (event) => {
    const tab = event.target instanceof Element && event.target.closest("[role=tab]")
    if (tab && this.tabs.includes(tab)) this.select(tab)
  }

  #keydown = (event) => {
    const tabs = this.tabs
    const index = tabs.indexOf(event.target)
    if (index === -1) return

    const targets = { ArrowRight: index + 1, ArrowLeft: index - 1, Home: 0, End: tabs.length - 1 }
    if (!(event.key in targets)) return

    event.preventDefault()
    this.select(tabs[(targets[event.key] + tabs.length) % tabs.length], { focus: true })
  }

  #restore = () => {
    const key = this.#storageKey
    if (!key) return

    let id
    try {
      id = sessionStorage.getItem(key)
    } catch {
      return
    }

    const tab = id && this.tabs.find((each) => each.id === id)
    if (tab) this.select(tab, { remember: false })
  }

  get #storageKey() {
    return this.id ? `unmagic-tabs:${location.pathname}:${this.id}` : null
  }
}

customElements.get("unmagic-tabs") || customElements.define("unmagic-tabs", UnmagicTabs)
