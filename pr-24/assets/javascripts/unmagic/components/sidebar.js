// <unmagic-sidebar> — the navigation down the side of an app, rendered by
// `sidebar`. The <nav> inside is a popover, so below the breakpoint the toggle
// opens it as a sheet from the edge with no script; above it, CSS lays it out
// inline. The element adds focus on the current link when the sheet opens,
// closing when a link inside it is followed (Turbo keeps the page alive, so it
// would otherwise stay open over the next page), closing before Turbo caches
// the page, and unmagic-sidebar:toggle with { open }.

class UnmagicSidebar extends HTMLElement {
  constructor() {
    super()
    this.addEventListener("toggle", this.#toggled, true)
    this.addEventListener("click", this.#clicked)
  }

  connectedCallback() {
    document.addEventListener("turbo:before-cache", this.#close)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.#close)
  }

  get panel() {
    return this.querySelector(":scope > nav")
  }

  #toggled = (event) => {
    if (event.target !== this.panel) return
    const open = event.newState === "open"
    if (open) (this.panel.querySelector("a[aria-current=page]") ?? this.panel.querySelector("a[href]"))?.focus()
    this.dispatchEvent(new CustomEvent("unmagic-sidebar:toggle", { bubbles: true, detail: { open } }))
  }

  #clicked = (event) => {
    if (event.target instanceof Element && event.target.closest("a[href]")) setTimeout(() => this.#close())
  }

  #close = () => {
    const panel = this.panel
    if (panel?.matches(":popover-open")) panel.hidePopover()
  }
}

customElements.get("unmagic-sidebar") || customElements.define("unmagic-sidebar", UnmagicSidebar)
