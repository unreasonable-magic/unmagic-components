// <unmagic-menu> — a dropdown of actions, rendered by `menu`.
//
// The markup is a popovertarget button and a popover="auto" panel, so before
// this script upgrades it the trigger opens and closes the panel natively, with
// light dismiss and Escape, and the panel sits where the UA puts a popover. The
// element adds:
//   - placement against the trigger through unmagic/components/position, kept
//     while the panel is open; on a narrow screen the panel is a sheet along the
//     bottom of the screen instead
//   - arrow keys, Home and End between items, and focus on the first item when
//     opened from the keyboard
//   - closing on choosing an item, on Tab, and before Turbo caches the page
//   - aria-expanded on the trigger, kept true to the panel
//
// <unmagic-context-menu for="ID"> is the same panel opened at the pointer on a
// right-click or a long press on the element with that id, or at the element's
// corner on Shift+F10.

import { anchor, placeAt, sheet } from "unmagic/components/position"

const ITEMS = "[role=menuitem]:not([disabled]):not([aria-disabled=true])"
const LONG_PRESS = 500

export class UnmagicMenu extends HTMLElement {
  #openedFromKeyboard = false
  #release = null

  constructor() {
    super()
    // toggle doesn't bubble, so listen on the way down.
    this.addEventListener("toggle", this.#toggled, true)
    this.addEventListener("keydown", this.#keydown)
    this.addEventListener("click", this.#clicked)
  }

  connectedCallback() {
    this.#expanded(false)
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

  get items() {
    return [...(this.panel?.querySelectorAll(ITEMS) ?? [])]
  }

  get isOpen() {
    return this.panel?.matches(":popover-open") ?? false
  }

  open({ keyboard = false } = {}) {
    this.#openedFromKeyboard = keyboard
    if (!this.isOpen) this.panel?.showPopover()
  }

  close({ focus = false } = {}) {
    if (!this.isOpen) return

    this.panel.hidePopover()
    if (focus) this.trigger?.focus()
  }

  // Where the panel goes once open. A menu anchors to its trigger.
  place(panel) {
    const trigger = this.trigger
    if (!trigger) return null
    return anchor(panel, trigger, { side: "bottom", align: this.getAttribute("align") === "start" ? "start" : "end", gap: 4 })
  }

  #toggled = (event) => {
    const panel = this.panel
    if (event.target !== panel) return

    if (event.newState === "open") {
      if (sheet()) {
        panel.setAttribute("data-sheet", "")
      } else {
        panel.removeAttribute("data-sheet")
        this.#release = this.place(panel)
      }
      this.#expanded(true)
      if (this.#openedFromKeyboard) this.items[0]?.focus()
      else panel.focus?.()
    } else {
      this.#release?.()
      this.#release = null
      panel.removeAttribute("data-sheet")
      this.#expanded(false)
    }
    this.#openedFromKeyboard = false
  }

  #expanded(open) {
    this.trigger?.setAttribute("aria-expanded", String(open))
  }

  #keydown = (event) => {
    if (event.target === this.trigger && !this.isOpen) {
      if (event.key === "Enter" || event.key === " ") this.#openedFromKeyboard = true
      if (event.key === "ArrowDown") {
        event.preventDefault()
        this.open({ keyboard: true })
      }
      return
    }

    if (!this.isOpen) return

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
  // button_to's form before the browser submits it. A click on the panel's dead
  // space is stopped, so a menu inside a <summary> doesn't flip its details.
  #clicked = (event) => {
    const target = event.target
    if (!(target instanceof Element) || !this.panel?.contains(target)) return

    if (target.closest(ITEMS)) setTimeout(() => this.close())
    else if (!target.closest("button, a, input, select, textarea, label, summary, details")) event.preventDefault()
  }

  #beforeCache = () => {
    this.close()
  }
}

export class UnmagicContextMenu extends UnmagicMenu {
  #region = null
  #timer = null
  #point = null
  #restore = null

  connectedCallback() {
    super.connectedCallback()
    this.#region = document.getElementById(this.getAttribute("for") ?? "")
    if (!this.#region) return

    this.#region.addEventListener("contextmenu", this.#contextmenu)
    this.#region.addEventListener("keydown", this.#shortcut)
    this.#region.addEventListener("pointerdown", this.#pressed)
    this.#region.addEventListener("pointerup", this.#released)
    this.#region.addEventListener("pointercancel", this.#released)
    this.#region.addEventListener("pointermove", this.#released)
  }

  disconnectedCallback() {
    super.disconnectedCallback()
    if (!this.#region) return

    this.#region.removeEventListener("contextmenu", this.#contextmenu)
    this.#region.removeEventListener("keydown", this.#shortcut)
    this.#region.removeEventListener("pointerdown", this.#pressed)
    this.#region.removeEventListener("pointerup", this.#released)
    this.#region.removeEventListener("pointercancel", this.#released)
    this.#region.removeEventListener("pointermove", this.#released)
  }

  get trigger() {
    return null
  }

  place(panel) {
    if (this.#point) {
      placeAt(panel, this.#point)
      return null
    }
    const rect = this.#region.getBoundingClientRect()
    placeAt(panel, { x: rect.left, y: rect.top })
    return null
  }

  openAt(point, { keyboard = false } = {}) {
    this.#point = point
    this.#restore = document.activeElement
    this.open({ keyboard })
  }

  close(options = {}) {
    const restore = this.#restore
    this.#restore = null
    this.#point = null
    super.close()
    if (options.focus) restore?.focus?.()
  }

  #contextmenu = (event) => {
    event.preventDefault()
    this.openAt({ x: event.clientX, y: event.clientY })
  }

  #shortcut = (event) => {
    if (event.key === "ContextMenu" || (event.key === "F10" && event.shiftKey)) {
      event.preventDefault()
      this.openAt(null, { keyboard: true })
    }
  }

  // A long press on a touch screen is the right-click a finger hasn't got.
  #pressed = (event) => {
    if (event.pointerType !== "touch") return
    clearTimeout(this.#timer)
    const point = { x: event.clientX, y: event.clientY }
    this.#timer = setTimeout(() => this.openAt(point), LONG_PRESS)
  }

  #released = () => clearTimeout(this.#timer)
}

customElements.get("unmagic-menu") || customElements.define("unmagic-menu", UnmagicMenu)
customElements.get("unmagic-context-menu") || customElements.define("unmagic-context-menu", UnmagicContextMenu)
