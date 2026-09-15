// <unmagic-toasts> — the toasts a layout mounts with `flash_toasts`.
//
// Each toast arrives as an inert <template data-unmagic-toast-template> inside the
// element: rendered with the page, morphed in by a refresh, or appended by
// turbo_stream.toast. The element clones each one into its stack, animates it in,
// and dismisses it after the element's `duration` (milliseconds). Hovering or
// focusing a toast holds it open.
//
// The stack is data-turbo-permanent, so a toast on screen survives a Drive visit
// or a morph. Its timer lives here, in the module, keyed by the toast rather than
// by the element, because Turbo moves the stack into a fresh <unmagic-toasts> on
// every visit.
//
// The stack is also a manual popover. Showing it puts it in the top layer, where a
// toast can appear above an open modal dialog; showing it again after a dialog
// opens lifts it back above. It is only seen there, not touched: a modal dialog
// makes everything outside it inert, top-layer popovers included, so a toast over
// one can't be hovered or dismissed until the dialog closes. It still times out.

const DURATION = 5000
const LEAVE = 200
const MINIMUM_AFTER_HOLD = 1000

const timers = new WeakMap()

class UnmagicToasts extends HTMLElement {
  #observer = new MutationObserver(() => this.#consume())

  connectedCallback() {
    this.#observer.observe(this, { childList: true })
    this.addEventListener("click", this.#dismiss)
    this.addEventListener("pointerover", this.#hold)
    this.addEventListener("focusin", this.#hold)
    this.addEventListener("pointerout", this.#release)
    this.addEventListener("focusout", this.#release)
    document.addEventListener("turbo:render", this.#lift)

    this.stack?.querySelectorAll("[data-unmagic-toast]").forEach((toast) => schedule(toast, this.duration))
    this.#consume()
    this.#lift()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
    this.removeEventListener("click", this.#dismiss)
    this.removeEventListener("pointerover", this.#hold)
    this.removeEventListener("focusin", this.#hold)
    this.removeEventListener("pointerout", this.#release)
    this.removeEventListener("focusout", this.#release)
    document.removeEventListener("turbo:render", this.#lift)
  }

  get stack() {
    return this.querySelector(":scope > .UnmagicToasts__stack")
  }

  get duration() {
    const duration = Number(this.getAttribute("duration"))
    return duration > 0 ? duration : DURATION
  }

  #consume() {
    const stack = this.stack
    const templates = this.querySelectorAll(":scope > template[data-unmagic-toast-template]")
    if (!stack || templates.length === 0) return

    for (const template of templates) {
      // Consume the source first, so a later morph or mutation can't pop it twice.
      template.remove()

      const toast = template.content.firstElementChild?.cloneNode(true)
      if (!toast) continue

      stack.append(toast)
      toast.getBoundingClientRect() // commit the starting style so the entrance transitions
      toast.setAttribute("data-open", "")
      schedule(toast, this.duration)
    }

    this.#lift()
  }

  #lift = () => {
    const stack = this.stack
    if (!stack?.showPopover) return

    const open = stack.matches(":popover-open")
    if (!stack.querySelector("[data-unmagic-toast]")) {
      if (open) stack.hidePopover()
      return
    }

    if (open) stack.hidePopover()
    stack.showPopover()
  }

  #dismiss = (event) => {
    const button = event.target instanceof Element && event.target.closest("[data-unmagic-toast-dismiss]")
    if (button) remove(button.closest("[data-unmagic-toast]"))
  }

  #hold = (event) => {
    const toast = event.target instanceof Element && event.target.closest("[data-unmagic-toast]")
    if (toast) pause(toast)
  }

  // pointerout and focusout also fire when moving between a toast's own children,
  // so wait a frame and ask whether it is still hovered or focused.
  #release = (event) => {
    const toast = event.target instanceof Element && event.target.closest("[data-unmagic-toast]")
    if (!toast) return

    requestAnimationFrame(() => {
      if (!toast.matches(":hover, :focus-within")) resume(toast)
    })
  }
}

function schedule(toast, duration) {
  if (timers.has(toast)) return

  const entry = { remaining: duration, started: 0, timer: null }
  timers.set(toast, entry)
  start(toast, entry)
}

function start(toast, entry) {
  entry.started = Date.now()
  entry.timer = setTimeout(() => remove(toast), entry.remaining)
}

function pause(toast) {
  const entry = timers.get(toast)
  if (!entry || entry.timer === null) return

  clearTimeout(entry.timer)
  entry.timer = null
  entry.remaining -= Date.now() - entry.started
}

// Give the reader a moment after letting go, even if the time was nearly up.
function resume(toast) {
  const entry = timers.get(toast)
  if (!entry || entry.timer !== null) return

  entry.remaining = Math.max(entry.remaining, MINIMUM_AFTER_HOLD)
  start(toast, entry)
}

function remove(toast) {
  if (!toast || toast.hasAttribute("data-leaving")) return

  const entry = timers.get(toast)
  if (entry?.timer) clearTimeout(entry.timer)
  timers.delete(toast)

  toast.setAttribute("data-leaving", "")
  toast.removeAttribute("data-open")

  const stack = toast.parentElement
  const leave = matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : LEAVE

  setTimeout(() => {
    toast.remove()
    if (stack?.hidePopover && stack.matches(":popover-open") && !stack.querySelector("[data-unmagic-toast]")) {
      stack.hidePopover()
    }
  }, leave)
}

customElements.get("unmagic-toasts") || customElements.define("unmagic-toasts", UnmagicToasts)
