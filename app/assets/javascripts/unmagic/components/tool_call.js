// <unmagic-tool-call name="…" state="…"> — one reach for a tool, as a row in a
// timeline, rendered by `ai_chat_tool_call`.
//
// The markup is native and the element leaves it alone: a <details> fold whose
// <summary> is the row, payloads inside the fold as <figure>s, the result after
// it. CSS reads the state off the host's attribute, which readings show
// included. What this adds:
//
//   state="queued|running|waiting|done|failed"   reflected as a property; an
//                                                unknown state reads as queued, and
//                                                assigning one throws
//   name="…"                                     reflected as a property; a
//                                                hand-written summary without a
//                                                <code> gets one from it
//   label-<state>="…"                            the translated status words
//
// It owns one node, the glyph first in the summary: the state's icon and a
// visually hidden status word, which it redraws when the state or a label
// changes, setting aria-busy on the host while running. Ruby seeds the glyph
// with the state it drew, so the first render changes nothing. A fold with
// nothing in it is kept out of the tab order until a payload arrives, since a
// chevron that opens onto nothing is a trap for the keyboard. The fold's open
// or shut is remembered by ai_chat under the host's id.
//
// The tool_call_state Turbo Stream action sets state from the server:
//
//   <turbo-stream action="tool_call_state" targets="#call_9" state="done"></turbo-stream>
import { Turbo } from "@hotwired/turbo-rails"
import "unmagic/components/ai_chat"
import "unmagic/components/elapsed"
import { toolCallIcons } from "unmagic/components/tool_call_icons"

const STATES = ["queued", "running", "waiting", "done", "failed"]
const LABELS = { queued: "Queued", running: "Running", waiting: "Waiting on you", done: "Done", failed: "Failed" }

class UnmagicToolCall extends HTMLElement {
  static observedAttributes = ["state", "name", ...STATES.map(state => `label-${state}`)]
  #observer = new MutationObserver(() => this.#render())

  connectedCallback() {
    // Honour property assignments made before the element definition loaded.
    for (const property of ["state", "name"]) {
      if (!Object.hasOwn(this, property)) continue
      const value = this[property]
      delete this[property]
      this[property] = value
    }
    this.#render()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
  }

  attributeChangedCallback() {
    if (this.isConnected) this.#render()
  }

  get state() {
    const value = this.getAttribute("state")
    return STATES.includes(value) ? value : "queued"
  }

  set state(value) {
    if (!STATES.includes(value)) throw new TypeError(`Unknown tool call state: ${value}`)
    this.setAttribute("state", value)
  }

  get name() {
    return this.getAttribute("name") ?? ""
  }

  set name(value) {
    this.setAttribute("name", value)
  }

  #render() {
    this.#observer.disconnect()
    try {
      const details = this.querySelector(":scope > details")
      const summary = details?.querySelector(":scope > summary")
      if (!summary) return
      this.#keepName(summary)
      this.#keepGlyph(summary)
      // An empty fold has nothing to open onto, so it is not a stop for Tab.
      const empty = !details.querySelector(":scope > :not(summary)")
      if (empty) summary.tabIndex = -1
      else summary.removeAttribute("tabindex")
    } finally {
      if (this.isConnected) this.#observer.observe(this, { childList: true, subtree: true })
    }
  }

  #keepName(summary) {
    let code = summary.querySelector(":scope > code")
    if (!code && this.hasAttribute("name")) {
      code = document.createElement("code")
      code.dataset.toolCallName = ""
      summary.querySelector(":scope > [data-tool-call-glyph]")?.after(code) ?? summary.prepend(code)
    }
    // Only a name the element wrote follows the attribute; one the server wrote is the server's.
    if (code?.hasAttribute("data-tool-call-name") && code.textContent !== this.name) code.textContent = this.name
  }

  #keepGlyph(summary) {
    const state = this.state
    const label = this.getAttribute(`label-${state}`) ?? LABELS[state]
    let glyph = summary.querySelector(":scope > [data-tool-call-glyph]")
    if (!glyph) {
      glyph = document.createElement("span")
      glyph.dataset.toolCallGlyph = ""
    }
    if (summary.firstElementChild !== glyph) summary.prepend(glyph)
    if (state === "running") this.setAttribute("aria-busy", "true")
    else this.removeAttribute("aria-busy")

    const status = glyph.querySelector(":scope > .UnmagicVisuallyHidden")
    if (glyph.dataset.toolCallGlyph === state && status?.textContent === label) return

    const custom = glyph.querySelector(":scope > template")
    const template = document.createElement("template")
    template.innerHTML = toolCallIcons[state]
    const icon = ((state === "done" && custom?.content.querySelector("svg")) || template.content.firstElementChild).cloneNode(true)
    icon.setAttribute("aria-hidden", "true")
    icon.classList.add("UnmagicIcon")
    icon.classList.toggle("UnmagicAIChatSpinner", state === "running")
    const word = document.createElement("span")
    word.className = "UnmagicVisuallyHidden"
    word.textContent = label
    glyph.replaceChildren(icon, ...(custom ? [ custom ] : []), word)
    glyph.dataset.toolCallGlyph = state
  }
}

customElements.get("unmagic-tool-call") || customElements.define("unmagic-tool-call", UnmagicToolCall)

Turbo.StreamActions.tool_call_state = function () {
  for (const element of this.targetElements) element.setAttribute("state", this.getAttribute("state"))
}
