// <unmagic-popover placement="bottom" align="start"> — a small panel of content
// behind a trigger, rendered by `popover`.
//
// The markup is a popovertarget button and a popover="auto" sibling panel with
// role="dialog", so before upgrade the trigger opens and closes it natively with
// light dismiss and Escape. The element adds placement against the trigger
// (unmagic/components/position), a sheet along the bottom on a narrow screen,
// focus into the panel on open and back to the trigger on Escape, closing when
// Tab leaves the panel, aria-expanded on the trigger, and the events
// unmagic-popover:open and unmagic-popover:close.

import { anchor, sheet } from "unmagic/components/position"

const FOCUSABLE = "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"

class UnmagicPopover extends HTMLElement {
  #release = null
  #escaped = false

  constructor() {
    super()
    this.addEventListener("toggle", this.#toggled, true)
    this.addEventListener("keydown", this.#keydown)
    this.addEventListener("focusout", this.#focusout)
  }

  connectedCallback() {
    this.trigger?.setAttribute("aria-expanded", "false")
    document.addEventListener("turbo:before-cache", this.#beforeCache)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.#beforeCache)
    this.#release?.()
  }

  get trigger() {
    return this.querySelector(":scope > [popovertarget]")
  }

  get panel() {
    return this.querySelector(":scope > [popover]")
  }

  get isOpen() {
    return this.panel?.matches(":popover-open") ?? false
  }

  open() {
    if (!this.isOpen) this.panel?.showPopover()
  }

  close({ focus = false } = {}) {
    if (!this.isOpen) return
    this.panel.hidePopover()
    if (focus) this.trigger?.focus()
  }

  #toggled = (event) => {
    const panel = this.panel
    if (event.target !== panel) return

    if (event.newState === "open") {
      if (sheet()) {
        panel.setAttribute("data-sheet", "")
      } else {
        panel.removeAttribute("data-sheet")
        this.#release = anchor(panel, this.trigger, {
          side: this.getAttribute("placement") === "top" ? "top" : "bottom",
          align: this.getAttribute("align") ?? "start",
          gap: 6
        })
      }
      this.trigger?.setAttribute("aria-expanded", "true")
      const first = panel.querySelector(FOCUSABLE)
      if (first) first.focus()
      else panel.focus()
      this.dispatchEvent(new CustomEvent("unmagic-popover:open", { bubbles: true }))
    } else {
      this.#release?.()
      this.#release = null
      panel.removeAttribute("data-sheet")
      this.trigger?.setAttribute("aria-expanded", "false")
      if (this.#escaped || panel.contains(document.activeElement) || document.activeElement === document.body) this.trigger?.focus()
      this.#escaped = false
      this.dispatchEvent(new CustomEvent("unmagic-popover:close", { bubbles: true }))
    }
  }

  #keydown = (event) => {
    if (event.key === "Escape" && this.isOpen) this.#escaped = true
  }

  // Tab out of the last item closes the panel; focus carries on after the trigger.
  #focusout = (event) => {
    const panel = this.panel
    if (!this.isOpen || !panel) return
    const next = event.relatedTarget
    if (next instanceof Node && (panel.contains(next) || this.trigger?.contains(next))) return
    if (next) this.close()
  }

  #beforeCache = () => this.close()
}

customElements.get("unmagic-popover") || customElements.define("unmagic-popover", UnmagicPopover)
