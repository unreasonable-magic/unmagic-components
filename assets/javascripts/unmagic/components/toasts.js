// <unmagic-toasts> — shared lifecycle for Rails templates and the `toast` JS API.
// The mount supplies Ruby-rendered blueprints, labels and icons. JS fills plain
// text and binds actions; it never interprets message/title strings as HTML.
// Six permanent regions keep active nodes and callbacks through Turbo moves.
// Registry reconciliation drops stale snapshot clones, and removal releases
// timers/callbacks. Scoped mounts stay within their positioned ancestor.
// Modal dialogs still make outside toasts inert, even in the top layer.
// Events: unmagic-toast:show/update/dismiss/action-error/error, bubbling on mount.

const DEFAULT_TARGET = "unmagic_toasts"
const DURATION = 5000
const LEAVE = 200
const MINIMUM_AFTER_HOLD = 1000
const TONES = ["good", "warn", "bad", "info", "neutral", "accent", "inverted"]
const POSITIONS = ["top_start", "top", "top_end", "bottom_start", "bottom", "bottom_end"]
const WIDTHS = { short: 384, long: 560 }
const FIELDS = ["message", "title", "tone", "duration", "position", "width", "layout", "closeButton", "icon", "actions"]
const active = new Map()
const records = new WeakMap()
let sequence = 0

function emit(mount, name, detail) {
  mount?.dispatchEvent(new CustomEvent(`unmagic-toast:${name}`, { bubbles: true, detail }))
}

function object(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new TypeError(`${label} must be an object`)
}

function string(value, label) {
  if (typeof value !== "string" || !value.trim()) throw new TypeError(`${label} must be a nonblank string`)
}

function validate(options, keys = FIELDS) {
  object(options, "Toast options")
  for (const key of Object.keys(options)) {
    if (!keys.includes(key)) throw new TypeError(`Unknown toast option: ${key}`)
    const value = options[key]
    if (key === "message" && typeof value !== "string") throw new TypeError("Toast message must be a string")
    if (key === "title" && value !== null && typeof value !== "string") throw new TypeError("Toast title must be a string or null")
    if (key === "tone" && !TONES.includes(value)) throw new TypeError("Unknown toast tone")
    if (key === "position" && !POSITIONS.includes(value)) throw new TypeError("Unknown toast position")
    if (key === "layout" && !["horizontal", "vertical"].includes(value)) throw new TypeError("Unknown toast layout")
    if (key === "duration" && !(Number.isFinite(value) && value >= 0)) throw new TypeError("Toast duration must be finite nonnegative milliseconds")
    if (key === "width" && !Object.hasOwn(WIDTHS, value) && !(Number.isInteger(value) && value > 0)) throw new TypeError("Toast width must be short, long, or positive integer pixels")
    if (key === "closeButton" && typeof value !== "boolean") throw new TypeError("Toast closeButton must be boolean")
    if (key === "icon" && value !== null && value !== false) throw new TypeError("Toast icon must be null (default) or false")
    if (["id", "target"].includes(key)) string(value, key)
    if (key === "actions") {
      if (!Array.isArray(value)) throw new TypeError("Toast actions must be an array")
      for (const action of value) {
        object(action, "Toast action")
        if (Object.keys(action).some(key => !["label", "onClick", "dismiss"].includes(key))) throw new TypeError("Unknown toast action option")
        string(action.label, "Action label")
        if (Object.hasOwn(action, "onClick") && typeof action.onClick !== "function") throw new TypeError("Action onClick must be a function")
        if (Object.hasOwn(action, "dismiss") && typeof action.dismiss !== "boolean") throw new TypeError("Action dismiss must be boolean")
      }
    }
  }
}

function contentPresent(options) {
  if (!options.message.trim() && !options.title?.trim()) throw new TypeError("A toast needs a message or title")
}

function copyOptions(options) {
  return { ...options, ...(options.actions && { actions: options.actions.map(action => ({ ...action })) }) }
}

function mountFor(record) { return record.node.closest("unmagic-toasts") }
function current(record) { return active.get(record.id) === record && !record.leaving }
function held(record) { return record.pending.size > 0 || record.node.matches(":hover, :focus-within") }

function pause(record) {
  if (record.timer === null) return
  clearTimeout(record.timer)
  record.timer = null
  record.remaining = Math.max(0, record.remaining - (performance.now() - record.started))
}

function runTimer(record) {
  if (!current(record) || record.options.duration === 0 || record.timer !== null || held(record)) return
  record.started = performance.now()
  // Chunk very long durations rather than letting setTimeout overflow to 1ms.
  const delay = Math.min(record.remaining, 2147483647)
  record.timer = setTimeout(() => {
    pause(record)
    if (held(record)) return
    if (record.remaining > 1) runTimer(record)
    else remove(record, "timeout")
  }, delay)
}

function syncTimer(record) {
  if (!current(record)) return
  if (held(record)) pause(record)
  else if (record.timer === null && record.options.duration !== 0) {
    record.remaining = Math.max(record.remaining, MINIMUM_AFTER_HOLD)
    runTimer(record)
  }
}

function resetTimer(record, duration) {
  pause(record)
  record.remaining = duration
  runTimer(record)
}

function release(record) {
  pause(record)
  active.delete(record.id)
  records.delete(record.node)
  record.options.actions = null
  record.pending.clear()
  record.trigger = null
}

function cleanup() {
  for (const record of active.values()) {
    if (!record.node.isConnected || !mountFor(record)?.isConnected) release(record)
  }
}

function restoreFocus(record) {
  const control = record.node.querySelector('.UnmagicToast__dismiss, [data-unmagic-toast-dismiss]:not(:disabled), [data-toast-action]:not(:disabled)')
  if (control) control.focus({ preventScroll: true })
  else if (record.trigger?.isConnected) record.trigger.focus?.({ preventScroll: true })
}

function remove(record, reason) {
  if (!current(record)) return false
  const node = record.node
  const mount = mountFor(record)
  record.leaving = true
  pause(record)
  if (node.contains(document.activeElement) && record.trigger?.isConnected) record.trigger.focus?.({ preventScroll: true })
  node.setAttribute("data-leaving", "")
  node.removeAttribute("data-open")
  emit(mount, "dismiss", { id: record.id, reason })
  const delay = matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : LEAVE
  setTimeout(() => {
    node.remove()
    // An event listener may already have removed this node; release only its record.
    if (active.get(record.id) === record) release(record)
    lift(mount)
  }, delay)
  return true
}

function lift(mount) {
  for (const stack of mount?.querySelectorAll(":scope > .UnmagicToasts__stack") || []) {
    if (!stack.hasAttribute("popover") || !stack.showPopover || !stack.isConnected) continue
    const open = stack.matches(":popover-open")
    if (!stack.querySelector("[data-unmagic-toast]")) {
      if (open) stack.hidePopover()
    } else {
      if (open) stack.hidePopover()
      stack.showPopover()
    }
  }
}

export class UnmagicToasts extends HTMLElement {
  #observer = new MutationObserver(() => {
    this.#consume()
    requestAnimationFrame(cleanup)
  })

  constructor() {
    super()
    this.addEventListener("click", this.#click)
    this.addEventListener("pointerover", this.#hold)
    this.addEventListener("focusin", this.#hold)
    this.addEventListener("pointerout", this.#release)
    this.addEventListener("focusout", this.#release)
  }

  connectedCallback() {
    this.#observer.observe(this, { childList: true, subtree: true })
    document.addEventListener("turbo:render", this.#lift)
    document.addEventListener("toggle", this.#dialogToggle, true)
    // Only registry-backed nodes are live. Cached copies must not resurrect a
    // dismissed toast or an action whose callback has already been released.
    for (const node of this.querySelectorAll(".UnmagicToasts__stack > [data-unmagic-toast]")) {
      const record = active.get(node.dataset.toastId)
      if (!record || record.node !== node || record.leaving) node.remove()
      else syncTimer(record)
    }
    this.#consume()
    this.#lift()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
    document.removeEventListener("turbo:render", this.#lift)
    document.removeEventListener("toggle", this.#dialogToggle, true)
    requestAnimationFrame(cleanup)
  }

  get duration() {
    const raw = this.getAttribute("duration")?.trim()
    const value = raw ? Number(raw) : NaN
    return Number.isFinite(value) && value >= 0 ? value : DURATION
  }

  get position() {
    const value = this.getAttribute("position")
    return POSITIONS.includes(value) ? value : "top_end"
  }

  #part(selector) {
    const blueprint = this.querySelector(":scope > template[data-unmagic-toast-blueprint]")
    const node = blueprint?.content.querySelector(selector)
    if (!node) throw new Error("Toast mount is missing its Ruby-rendered blueprint; render flash_toasts with the current gem")
    return node.cloneNode(true)
  }

  #stack(position) {
    const stack = [...this.querySelectorAll(":scope > .UnmagicToasts__stack")].find(node => node.dataset.position === position)
    if (!stack) throw new Error(`Toast mount has no ${position} region`)
    return stack
  }

  show(message, options = {}) {
    if (!this.isConnected) throw new Error("Toast mount is not connected")
    validate(options, [...FIELDS.filter(key => key !== "message"), "id"])
    validate({ message })
    const config = copyOptions({ title: null, tone: "good", duration: this.duration, position: this.position,
      width: "short", layout: "horizontal", closeButton: true, icon: null, actions: [], ...options, message })
    contentPresent(config)
    const id = options.id || `unmagic_toast_${Date.now().toString(36)}_${++sequence}`
    if (active.has(id)) throw new Error(`Toast id already exists: ${id}`)
    const node = this.#part(".UnmagicToast")
    this.#paint(node, config, Object.keys(config))
    return this.#insert(node, config, id, "javascript")
  }

  update(id, patch) {
    const record = active.get(id)
    if (!record || !current(record) || mountFor(record) !== this) return false
    validate(patch)
    const config = copyOptions({ ...record.options, ...patch })
    if (Object.hasOwn(patch, "message") || Object.hasOwn(patch, "title")) contentPresent(config)
    // Validate region before touching the live node.
    this.#stack(config.position)
    const focused = document.activeElement
    const hadFocus = record.node.contains(focused)
    this.#paint(record.node, config, Object.keys(patch))
    if (Object.hasOwn(patch, "actions")) record.actionsVersion++
    record.options = config
    if (Object.hasOwn(patch, "position")) this.#stack(config.position).append(record.node)
    this.#lift()
    if (hadFocus) {
      if (focused.isConnected) focused.focus?.({ preventScroll: true })
      else restoreFocus(record)
    }
    if (Object.hasOwn(patch, "duration")) resetTimer(record, config.duration)
    else syncTimer(record)
    emit(this, "update", { id })
    return true
  }

  dismiss(id) {
    const record = active.get(id)
    return record && mountFor(record) === this ? remove(record, "api") : false
  }

  dismissAll() {
    let count = 0
    for (const record of [...active.values()]) {
      if (mountFor(record) === this && remove(record, "api")) count++
    }
    return count
  }

  #paint(node, config, keys) {
    const has = key => keys.includes(key)
    if (has("tone")) {
      node.classList.remove(...TONES.map(tone => `UnmagicToast--${tone}`))
      node.classList.add(`UnmagicToast--${config.tone}`)
      if (config.tone === "bad") node.setAttribute("role", "alert")
      else node.removeAttribute("role")
    }
    if (has("tone") || has("icon")) {
      if (config.icon !== "custom") {
        node.querySelector(":scope > .UnmagicToast__icon")?.remove()
        if (has("icon")) node.querySelector(":scope > .UnmagicToast__leading")?.remove()
        if (config.icon !== false) {
          const icon = this.querySelector(`:scope > template[data-unmagic-toast-icon="${config.tone}"]`)?.content.firstElementChild
          if (!icon) throw new Error("Toast mount is missing its tone icon blueprint")
          node.prepend(icon.cloneNode(true))
        }
        node.dataset.toastIcon = config.icon === false ? "none" : "default"
      }
    }
    const content = node.querySelector(".UnmagicToast__content")
    if (has("message") || has("title")) {
      if (!content.querySelector(".UnmagicToast__message")) {
        content.replaceChildren(...this.#part(".UnmagicToast__content").childNodes)
      }
      if (has("message")) content.querySelector(".UnmagicToast__message").textContent = config.message
      if (has("title")) {
        let title = content.querySelector(".UnmagicToast__title")
        if (config.title !== null) {
          if (!title) { title = this.#part(".UnmagicToast__title"); content.prepend(title) }
          title.textContent = config.title
        } else title?.remove()
      }
    }
    if (has("actions")) {
      let actions = node.querySelector(".UnmagicToast__actions")
      if (config.actions.length) {
        if (!actions) { actions = this.#part(".UnmagicToast__actions"); node.querySelector(".UnmagicToast__main").append(actions) }
        actions.replaceChildren(...config.actions.map((action, index) => {
          const button = this.#part(".UnmagicToast__actions button")
          button.textContent = action.label
          button.dataset.toastAction = String(index)
          return button
        }))
      } else actions?.remove()
    }
    if (has("closeButton")) {
      const close = node.querySelector(":scope > .UnmagicToast__dismiss")
      if (!config.closeButton) close?.remove()
      else if (!close) node.append(this.#part(".UnmagicToast__dismiss"))
    }
    if (has("width")) node.style.setProperty("--unmagic-toast-width", `${WIDTHS[config.width] || config.width}px`)
    if (has("layout")) node.dataset.layout = config.layout
    if (has("position")) node.dataset.position = config.position
    if (has("duration")) node.dataset.duration = String(config.duration)
  }

  #insert(node, config, id, source) {
    if (active.has(id)) throw new Error(`Toast id already exists: ${id}`)
    const stack = this.#stack(config.position)
    node.dataset.toastId = id
    node.dataset.toastSource = source
    node.dataset.duration = String(config.duration)
    node.dataset.position = config.position
    const record = { node, id, options: config, trigger: document.activeElement, remaining: config.duration,
      timer: null, started: 0, pending: new Set(), actionsVersion: 0, leaving: false }
    active.set(id, record)
    records.set(node, record)
    stack.append(node)
    this.#lift()
    node.getBoundingClientRect()
    node.setAttribute("data-open", "")
    runTimer(record)
    emit(this, "show", { id })
    return id
  }

  #consume() {
    for (const template of this.querySelectorAll(":scope > template[data-unmagic-toast-template]")) {
      template.remove()
      const node = template.content.firstElementChild?.cloneNode(true)
      if (!node) continue
      const raw = node.dataset.duration?.trim()
      const duration = raw ? Number(raw) : NaN
      const config = {
        message: node.querySelector(".UnmagicToast__message")?.textContent || "",
        title: node.querySelector(".UnmagicToast__title")?.textContent ?? null,
        tone: TONES.find(tone => node.classList.contains(`UnmagicToast--${tone}`)) || "good",
        duration: Number.isFinite(duration) && duration >= 0 ? duration : this.duration,
        position: POSITIONS.includes(node.dataset.position) ? node.dataset.position : this.position,
        width: parseInt(node.style.getPropertyValue("--unmagic-toast-width"), 10) || 384,
        layout: node.dataset.layout || "horizontal",
        closeButton: !!node.querySelector(".UnmagicToast__dismiss"),
        icon: node.dataset.toastIcon === "custom" ? "custom" : node.dataset.toastIcon === "none" ? false : null,
        actions: null,
      }
      const id = node.dataset.toastId || `unmagic_toast_${Date.now().toString(36)}_${++sequence}`
      try { this.#insert(node, config, id, "rails") }
      catch (error) { emit(this, "error", { id, error }) }
    }
  }

  // A newly opened dialog is last in the top layer. Re-show existing viewport
  // regions after it opens, even when no new notification is arriving.
  #dialogToggle = event => {
    if (event.target instanceof HTMLDialogElement && event.target.open) this.#lift()
  }

  #lift = () => lift(this)

  #record(event) {
    const node = event.target instanceof Element && event.target.closest("[data-unmagic-toast]")
    return node && node.closest("unmagic-toasts") === this ? records.get(node) : null
  }

  #click = (event) => {
    const record = this.#record(event)
    if (!record || !current(record)) return
    const action = event.target.closest("[data-toast-action]")
    if (action) { this.#action(record, action); return }
    const dismiss = event.target.closest("[data-unmagic-toast-dismiss]")
    if (dismiss) remove(record, dismiss.classList.contains("UnmagicToast__dismiss") ? "close" : "action")
  }

  #action = async (record, button) => {
    const action = record.options.actions?.[Number(button.dataset.toastAction)]
    if (!action || record.pending.has(button) || button.disabled) return
    const version = record.actionsVersion
    record.pending.add(button)
    pause(record)
    button.disabled = true
    button.setAttribute("aria-busy", "true")
    try {
      await action.onClick?.({ id: record.id })
      if (current(record) && version === record.actionsVersion && action.dismiss !== false) remove(record, "action")
    } catch (error) {
      if (current(record)) emit(mountFor(record), "action-error", { id: record.id, error })
    } finally {
      record.pending.delete(button)
      button.disabled = false
      button.removeAttribute("aria-busy")
      syncTimer(record)
    }
  }

  #hold = event => {
    const record = this.#record(event)
    if (record) pause(record)
  }

  #release = event => {
    const record = this.#record(event)
    // Focus settles after focusout; timers must resume even in background tabs.
    if (record) setTimeout(() => syncTimer(record), 0)
  }
}

function findMount(target = DEFAULT_TARGET) {
  string(target, "Toast target")
  const mount = document.getElementById(target)
  if (!(mount instanceof UnmagicToasts)) throw new Error(`Toast mount not found: ${target}. Render flash_toasts first.`)
  return mount
}

export const toast = Object.freeze({
  show(message, options = {}) {
    validate(options, [...FIELDS.filter(key => key !== "message"), "id", "target"])
    const { target = DEFAULT_TARGET, ...config } = options
    return findMount(target).show(message, config)
  },
  update(id, patch) {
    const record = active.get(id)
    return record && current(record) && record.node.isConnected ? mountFor(record)?.update(id, patch) ?? false : false
  },
  dismiss(id) {
    const record = active.get(id)
    return record && record.node.isConnected ? remove(record, "api") : false
  },
  dismissAll(options = {}) {
    validate(options, ["target"])
    return findMount(options.target).dismissAll()
  },
})

customElements.get("unmagic-toasts") || customElements.define("unmagic-toasts", UnmagicToasts)
