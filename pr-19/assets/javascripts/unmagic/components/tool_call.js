// <unmagic-tool-call> — progressive disclosure, rendered by ai_chat_tool_call.
// Direct data-part="row", "payload" (repeatable), and "result" nodes are caller-owned.
// Without JS all content is readable. Append payloads to the host, remove by ID.
// open is the initial preference; identified calls share ai_chat's reader choice.
// state/name properties reflect attributes. State changes never replace payloads.
// label-{state} overrides English labels; formatted readings remain caller-owned.
import { restoreDisclosureChoices } from "unmagic/components/ai_chat"
import { toolCallIcons } from "unmagic/components/tool_call_icons"
import "unmagic/components/elapsed"

const LABELS = { queued: "Queued", running: "Running", waiting: "Waiting on you", done: "Done", failed: "Failed" }
const PART_CLASSES = {
  name: "UnmagicAIChatToolCall__name", summary: "UnmagicAIChatToolCall__summary",
  progress: "UnmagicAIChatToolCall__progress", readings: "UnmagicAIChatToolCall__readings",
  failures: "UnmagicAIChatToolCall__reading", elapsed: "UnmagicAIChatToolCall__reading", duration: "UnmagicAIChatToolCall__reading",
  result: "UnmagicAIChatToolCall__made"
}

class UnmagicToolCall extends HTMLElement {
  static observedAttributes = ["state", "name", ...Object.keys(LABELS).map(state => `label-${state}`)]
  #observer = new MutationObserver(() => this.#render())
  #open
  #details = null

  connectedCallback() {
    // Honor property assignments made before the element definition loaded.
    for (const property of ["state", "name"]) {
      if (!Object.hasOwn(this, property)) continue
      const value = this[property]
      delete this[property]
      this[property] = value
    }
    this.#render()
  }

  get state() {
    const value = this.getAttribute("state")
    return Object.hasOwn(LABELS, value) ? value : "queued"
  }

  set state(value) {
    if (!Object.hasOwn(LABELS, value)) throw new TypeError(`Unknown tool call state: ${value}`)
    this.setAttribute("state", value)
  }

  get name() { return this.getAttribute("name") ?? "" }
  set name(value) { this.setAttribute("name", value) }

  attributeChangedCallback(name, previous, value) {
    if (previous !== value && this.isConnected) this.#render()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
  }

  #parts(name) {
    return [...this.querySelectorAll(`[data-part="${name}"]`)]
      .filter(part => part.closest("unmagic-tool-call") === this)
  }

  #prepareRow() {
    this.classList.add("UnmagicAIChatToolCall")
    let row = this.#parts("row")[0]
    if (!row) {
      row = document.createElement("span")
      row.dataset.part = "row"
      this.prepend(row)
    }
    row.classList.add("UnmagicAIChatToolCall__row")
    for (const [part, className] of Object.entries(PART_CLASSES)) {
      for (const node of this.#parts(part)) {
        node.classList.add(className)
        if (part === "failures") node.classList.add("UnmagicAIChatToolCall__reading--warn")
        if (part !== "result" && node.parentElement === this) row.append(node)
      }
    }
    let name = this.#parts("name")[0]
    if (!name && this.hasAttribute("name")) {
      name = document.createElement("code")
      name.dataset.part = "name"
      name.dataset.toolCallName = ""
      name.className = PART_CLASSES.name
      row.prepend(name)
    }
    if (name?.hasAttribute("data-tool-call-name") && name.textContent !== this.name) name.textContent = this.name
    return row
  }

  #updateState(row) {
    const state = this.state
    for (const value of Object.keys(LABELS)) this.classList.toggle(`UnmagicAIChatToolCall--${value}`, value === state)
    if (state === "running") this.setAttribute("aria-busy", "true")
    else this.removeAttribute("aria-busy")
    let glyph = row.querySelector(':scope > [data-tool-call-glyph]')
    if (!glyph) {
      glyph = document.createElement("span")
      glyph.dataset.toolCallGlyph = ""
      glyph.className = "UnmagicAIChatToolCall__glyph"
      row.prepend(glyph)
    }
    if (row.firstElementChild !== glyph) row.prepend(glyph)
    const label = this.getAttribute(`label-${state}`) ?? LABELS[state]
    const custom = this.#parts("success-icon")[0]
    const key = `${state}:${label}:${state === "done" ? custom?.innerHTML ?? "" : ""}`
    if (glyph.dataset.renderKey !== key) {
      const template = document.createElement("template")
      template.innerHTML = toolCallIcons[state]
      const icon = (state === "done" && custom instanceof HTMLTemplateElement && custom.content.querySelector("svg")) || template.content.firstElementChild
      const clone = icon.cloneNode(true)
      clone.setAttribute("aria-hidden", "true")
      clone.classList.add("UnmagicIcon")
      clone.classList.toggle("UnmagicAIChatSpinner", state === "running")
      const status = document.createElement("span")
      status.className = "UnmagicVisuallyHidden"
      status.textContent = label
      glyph.replaceChildren(clone, status)
      glyph.dataset.renderKey = key
    }
    for (const node of this.#parts("status")) node.hidden = true
    const elapsed = this.#parts("elapsed")
    for (const part of ["progress", "failures", "elapsed", "duration"]) {
      for (const node of this.#parts(part)) {
        const visible = part === "progress" ? state === "running" :
          part === "failures" ? state !== "failed" :
          part === "elapsed" ? state === "running" : state !== "running" || !elapsed.length
        if (!visible && node.contains(document.activeElement)) {
          const focus = this.querySelector(":scope > details > summary") || row
          if (focus === row) row.tabIndex = -1
          focus.focus({ preventScroll: true })
        }
        node.hidden = !visible
      }
    }
    for (const readings of this.#parts("readings")) readings.hidden = ![...readings.children].some(node => !node.hidden)
  }

  #render() {
    this.#observer.disconnect()
    try {
      const row = this.#prepareRow()
      this.#updateState(row)
      let details = this.querySelector(':scope > details[data-tool-call-generated]')

      const payloads = [
        ...(details?.querySelectorAll(':scope > [data-tool-call-body] > [data-part="payload"]') || []),
        ...this.querySelectorAll(':scope > [data-part="payload"]')
      ]
      const focused = document.activeElement
      const hadFocus = this.contains(focused)

      if (payloads.length) {
        if (!details) {
          details = document.createElement("details")
          details.setAttribute("data-tool-call-generated", "")
          details.className = "UnmagicAIChatToolCall__disclosure"
          details.open = this.#open ?? this.hasAttribute("open")
          const summary = document.createElement("summary")
          summary.className = "UnmagicAIChatToolCall__row"
          const body = document.createElement("div")
          body.setAttribute("data-tool-call-body", "")
          body.className = "UnmagicAIChatToolCall__body"
          details.append(summary, body)
          row.before(details)
        }
        if (this.id) details.dataset.aiChatDisclosure = this.id
        else details.removeAttribute("data-ai-chat-disclosure")
        const summary = details.querySelector(":scope > summary")
        const body = details.querySelector(":scope > [data-tool-call-body]")
        if (row.parentElement !== summary) {
          summary.replaceChildren(row)
        }
        for (const payload of payloads) {
          if (payload.parentElement !== body) body.append(payload)
        }
        // Restore once per disclosure, not on every streamed child update: a
        // click's native toggle event may still be pending during that update.
        if (this.#details !== details) restoreDisclosureChoices(details)
        this.#details = details
        // Upgrading around a focused control must not hide that control.
        if (hadFocus && body.contains(focused)) details.open = true
      } else if (details) {
        this.#open = details.open
        const summaryFocused = focused === details.querySelector(":scope > summary")
        details.replaceWith(row)
        this.#details = null
        if (summaryFocused) {
          row.tabIndex = -1
          row.focus({ preventScroll: true })
        }
      }
      // DOM moves can blur an input even when its identity is preserved.
      if (hadFocus && focused.isConnected && document.activeElement !== focused) {
        focused.focus({ preventScroll: true })
      }
    } finally {
      if (this.isConnected) this.#observer.observe(this, { childList: true, subtree: true })
    }
  }
}

customElements.get("unmagic-tool-call") || customElements.define("unmagic-tool-call", UnmagicToolCall)
