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
//
// The tabs are found anywhere inside the element rather than as its children, so
// a panel can put the list in a card's bar and the panels in its body. A bar-style
// list scrolls sideways on a narrow screen; the chosen tab is scrolled into view
// on connect and on each change, and so is the current page in a bar of links,
// which has no element of its own.

const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"

// Scrolls a list sideways so the tab sits in its middle, where the list is wider
// than its box. Only ever sideways: the page's own scroll is left alone.
function reveal(tab, smooth = true) {
  const list = tab?.parentElement
  if (!list || list.scrollWidth <= list.clientWidth) return

  const left = tab.offsetLeft - (list.clientWidth - tab.offsetWidth) / 2
  list.scrollTo({ left, behavior: smooth && !matchMedia(REDUCED_MOTION).matches ? "smooth" : "auto" })
}

function revealCurrentLinks() {
  for (const link of document.querySelectorAll(".UnmagicTabs--bar .UnmagicTabs__list > [aria-current=page]")) {
    reveal(link, false)
  }
}

class UnmagicTabs extends HTMLElement {
  constructor() {
    super()
    this.addEventListener("click", this.#clicked)
    this.addEventListener("keydown", this.#keydown)
  }

  connectedCallback() {
    this.#restore()
    reveal(this.tabs.find((tab) => tab.getAttribute("aria-selected") === "true"), false)
    document.addEventListener("turbo:morph", this.#restore)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:morph", this.#restore)
  }

  get tabs() {
    return [...this.querySelectorAll("[role=tab]")].filter((tab) => tab.closest("unmagic-tabs") === this)
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
    reveal(tab)
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

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", revealCurrentLinks)
} else {
  revealCurrentLinks()
}
document.addEventListener("turbo:load", revealCurrentLinks)
document.addEventListener("turbo:frame-load", revealCurrentLinks)
