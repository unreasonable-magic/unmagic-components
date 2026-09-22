// <unmagic-toasts> — the toasts a layout mounts with `flash_toasts`.
//
// Each toast arrives as an inert <template data-unmagic-toast-template> inside the
// element: rendered with the page, morphed in by a refresh, or appended by
// turbo_stream.toast. The element clones each one into its stack, animates it in,
// and dismisses it after the element's `duration` (milliseconds), or keeps it up
// until it is dismissed when that is 0. A toast's data-duration overrides the mount.
// data-position selects one of six permanent regions; scoped mounts stay within
// a positioned ancestor. Hovering or focusing a toast holds it open. Actions
// marked data-unmagic-toast-dismiss dismiss their containing toast.
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
const triggers = new WeakMap()
const POSITIONS = ["top_start", "top", "top_end", "bottom_start", "bottom", "bottom_end"]

class UnmagicToasts extends HTMLElement {
  #observer = new MutationObserver(() => this.#consume())

  constructor() {
    super()
    this.addEventListener("click", this.#dismiss)
    this.addEventListener("pointerover", this.#hold)
    this.addEventListener("focusin", this.#hold)
    this.addEventListener("pointerout", this.#release)
    this.addEventListener("focusout", this.#release)
  }

  connectedCallback() {
    this.#observer.observe(this, { childList: true })
    document.addEventListener("turbo:render", this.#lift)
    this.querySelectorAll("[data-unmagic-toast]").forEach((toast) => {
      if (toast.hasAttribute("data-leaving")) toast.remove()
      else schedule(toast, this.duration)
    })
    this.#consume()
    this.#lift()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
    document.removeEventListener("turbo:render", this.#lift)
  }

  get stacks() {
    return this.querySelectorAll(":scope > .UnmagicToasts__stack")
  }

  #stackFor(toast) {
    const position = toast.dataset.position || this.getAttribute("position") || "top_end"
    const valid = POSITIONS.includes(position) ? position : "top_end"
    return this.querySelector(`:scope > .UnmagicToasts__stack[data-position="${valid}"]`)
      || this.stacks[0]
  }

  // `duration="0"` keeps a toast up until it is dismissed. Absent, empty, negative or unparseable
  // all fall back to the default rather than silently pinning every toast to the screen — which is
  // why this isn't `Number(attr) || DURATION`: Number(null) and Number("") are both 0, so a missing
  // attribute would have read as "never" too.
  get duration() {
    const raw = this.getAttribute("duration")?.trim()
    if (!raw) return DURATION

    const duration = Number(raw)
    return Number.isFinite(duration) && duration >= 0 ? duration : DURATION
  }

  #consume() {
    const templates = this.querySelectorAll(":scope > template[data-unmagic-toast-template]")
    if (!this.stacks.length || templates.length === 0) return

    for (const template of templates) {
      // Consume the source first, so a later morph or mutation can't pop it twice.
      template.remove()

      const toast = template.content.firstElementChild?.cloneNode(true)
      if (!toast) continue

      const stack = this.#stackFor(toast)
      triggers.set(toast, document.activeElement)
      stack.append(toast)
      toast.getBoundingClientRect() // commit the starting style so the entrance transitions
      toast.setAttribute("data-open", "")
      schedule(toast, this.duration)
    }

    this.#lift()
  }

  #lift = () => {
    for (const stack of this.stacks) {
      if (!stack.hasAttribute("popover") || !stack.showPopover) continue
      const open = stack.matches(":popover-open")
      if (!stack.querySelector("[data-unmagic-toast]")) {
        if (open) stack.hidePopover()
        continue
      }
      if (open) stack.hidePopover()
      stack.showPopover()
    }
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
  const raw = toast.dataset.duration?.trim()
  const override = raw ? Number(raw) : NaN
  if (Number.isFinite(override) && override >= 0) duration = override
  // Resolve once: permanent stacks and Turbo snapshots keep the same policy.
  toast.dataset.duration = String(duration)
  // A duration of 0 is a toast that waits to be dismissed: no timer, and so nothing for hold and
  // release to pause — both look the toast up in `timers` and leave when it isn't there.
  if (duration === 0) return

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

  if (toast.contains(document.activeElement)) {
    const trigger = triggers.get(toast)
    if (trigger?.isConnected && typeof trigger.focus === "function") trigger.focus({ preventScroll: true })
  }
  triggers.delete(toast)
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
