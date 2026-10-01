// <unmagic-optimistic container="#entries"> — draws a form's submission before
// the server has heard of it, rendered by `ai_chat_composer`.
//
// On the enclosing form's submit, the element clones its <template> and fills it
// from the form's fields:
//
//   data-optimistic-id="message[client_id]"    the element's id, from that field
//   data-optimistic-text="message[content]"    the element's text, from that field
//
// then places it by id, exactly as the `upsert` stream action does (placement.js):
// an element with that id already on the page is replaced, otherwise the clone
// goes into `container`. The server then broadcasts the real element under the
// same id and the two become one. Pair it with <unmagic-uuid-input> so both sides
// know the id up front. A required field keeps an empty form from submitting, so
// there's never a placeholder with no record coming for it.
//
//   container="#entries"   where a new element goes (required)
//   scroll="false"         don't scroll the new element into view
//
// It fires unmagic-optimistic:insert with the element. Needs Turbo, for the
// broadcast that reconciles what it drew.
import { place } from "unmagic/components/placement"

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

class UnmagicOptimistic extends HTMLElement {
  #form = null

  connectedCallback() {
    this.#form = this.closest("form")
    this.#form?.addEventListener("submit", this.#insert)
  }

  disconnectedCallback() {
    this.#form?.removeEventListener("submit", this.#insert)
    this.#form = null
  }

  // Not skipped when the event is already handled: Turbo prevents the native
  // submit to send it itself, which is exactly the submission to draw.
  #insert = () => {
    const template = this.querySelector(":scope > template")
    if (!template) return

    const clone = template.content.cloneNode(true)
    for (const node of clone.querySelectorAll("[data-optimistic-id]")) {
      node.id = this.#field(node.dataset.optimisticId)
    }
    for (const node of clone.querySelectorAll("[data-optimistic-text]")) {
      node.textContent = this.#field(node.dataset.optimisticText)
    }

    const incoming = clone.firstElementChild
    if (!incoming) return

    const placed = place(incoming, document.querySelector(this.getAttribute("container")))
    if (!placed) return

    if (this.getAttribute("scroll") !== "false") {
      placed.scrollIntoView({ block: "end", behavior: reducedMotion.matches ? "instant" : "smooth" })
    }
    this.dispatchEvent(new CustomEvent("unmagic-optimistic:insert", { bubbles: true, detail: { element: placed } }))
  }

  #field(name) {
    const field = this.#form?.elements.namedItem(name)
    return field && "value" in field ? field.value : ""
  }
}

customElements.get("unmagic-optimistic") || customElements.define("unmagic-optimistic", UnmagicOptimistic)
