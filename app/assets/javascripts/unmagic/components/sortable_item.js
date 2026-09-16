// <unmagic-sortable-item key="…" data-sortable-rank="…"> — one item in an
// <unmagic-sortable-list>, rendered by `sortable_list`'s item and `board`.
//
//   key                   names the record to the server
//   data-sortable-rank    its rank, read as a neighbour's when another item drops
//   data-sortable-label   what announcements call it; its text otherwise
//
// With a [data-sortable-handle] of its own inside (not one belonging to an item
// nested in it), only a press on a handle drags it, straight away, and the
// handle's own buttons and links stay clickable. Without one, the whole item
// drags once the pointer has moved a few pixels, so a click on a link in it still
// follows the link; a press in a text field never starts a drag. Handles are how
// touch screens drag, since an item without one scrolls the page instead.
//
// The keyboard stop is its first focusable handle, or the item itself (given a
// tabindex) when it has none. Space or Enter there picks it up; see
// sortable_session.js for the rest.
import { beginPointerDrag, beginKeyboardDrag, dragging, keyboardDragOf } from "unmagic/components/sortable_session"

const TYPING = "input, textarea, select, [contenteditable]:not([contenteditable=false])"
const INTERACTIVE = `a[href], button, summary, label, [role=button], ${TYPING}`

class UnmagicSortableItem extends HTMLElement {
  constructor() {
    super()
    this.addEventListener("pointerdown", this.#pointerdown)
    this.addEventListener("keydown", this.#keydown)
  }

  // A drag moves the element, and a morph refresh may too, so this runs again each
  // time; everything it does is safe to repeat. A morph also resets attributes to
  // the server's markup without reconnecting, so it runs after every morph too.
  connectedCallback() {
    this.setUp()
  }

  setUp() {
    const stop = this.keyboardStop
    if (stop === this && !this.hasAttribute("tabindex")) this.tabIndex = 0

    const list = this.list
    if (list && !this.hasAttribute(DRAGGING_COPY)) {
      const described = new Set((stop.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean))
      described.add(list.instructionsId)
      stop.setAttribute("aria-describedby", [...described].join(" "))
    }
  }

  get key() {
    return this.getAttribute("key")
  }

  get rank() {
    return this.getAttribute("data-sortable-rank")
  }

  get label() {
    return this.getAttribute("data-sortable-label") || this.textContent.replace(/\s+/g, " ").trim().slice(0, 80)
  }

  get list() {
    return this.closest("unmagic-sortable-list")
  }

  get handles() {
    return [...this.querySelectorAll("[data-sortable-handle]")].filter(
      (handle) => handle.closest("unmagic-sortable-item") === this,
    )
  }

  get keyboardStop() {
    return this.handles.find((handle) => handle.matches("button, a[href], [tabindex]")) ?? this
  }

  #pointerdown = (event) => {
    if (event.button !== 0 || dragging()) return
    if (event.target.closest("unmagic-sortable-item") !== this) return

    const handles = this.handles
    const handle = event.target.closest("[data-sortable-handle]")
    const own = handle && handles.includes(handle) ? handle : null
    if (handles.length > 0 && !own) return

    const control = event.target.closest(own ? INTERACTIVE : TYPING)
    if (control && control !== own && this.contains(control)) return

    beginPointerDrag(this, event, { immediate: Boolean(own) })
  }

  #keydown = (event) => {
    const drag = keyboardDragOf(this)
    if (drag) return drag.key(event)
    if (dragging() || (event.key !== " " && event.key !== "Enter")) return

    const stop = this.keyboardStop
    if (event.target !== stop) return

    event.preventDefault()
    event.stopPropagation()
    beginKeyboardDrag(this, stop)
  }
}

const DRAGGING_COPY = "data-sortable-dragging"

const INSTALLED = Symbol.for("unmagic.components.sortable_item")
if (!document[INSTALLED]) {
  document[INSTALLED] = true
  document.addEventListener("turbo:morph", () => {
    for (const item of document.querySelectorAll("unmagic-sortable-item")) item.setUp?.()
  })
}

customElements.get("unmagic-sortable-item") || customElements.define("unmagic-sortable-item", UnmagicSortableItem)

export { UnmagicSortableItem }
