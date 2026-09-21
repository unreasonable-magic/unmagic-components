// <unmagic-elapsed since="…"> — a clock counting up from a moment the server
// named, rendered by `elapsed_tag`.
//
// Work that takes a minute and work that has hung look the same behind a spinner;
// a number that keeps moving is the difference. The server draws the first reading,
// so this only keeps it moving, a second at a time.
//
//   since="2026-09-16T12:00:00.000Z"   count up from this instant
//   until="2026-09-16T12:05:00.000Z"   or count down to it, stopping at zero and
//                                      firing unmagic-elapsed:end
//
// The words match Unmagic::Components::Duration in Ruby — 2s, 3m 5s, 1h 4m 2s —
// in whole seconds, floored going up and ceiled going down. Change both together.

class UnmagicElapsed extends HTMLElement {
  static observedAttributes = ["since", "until"]

  #timer = null
  #ended = false

  connectedCallback() {
    this.#ended = false
    this.#draw()
    this.#timer = setInterval(() => this.#draw(), 1000)
  }

  disconnectedCallback() {
    clearInterval(this.#timer)
    this.#timer = null
  }

  attributeChangedCallback() {
    if (!this.isConnected) return
    this.#ended = false
    this.#draw()
  }

  #draw() {
    const until = this.getAttribute("until")
    const now = Date.now()

    if (until) {
      const left = Math.max(0, Math.ceil((Date.parse(until) - now) / 1000))
      this.textContent = reading(left)
      if (left === 0 && !this.#ended) {
        this.#ended = true
        clearInterval(this.#timer)
        this.dispatchEvent(new CustomEvent("unmagic-elapsed:end", { bubbles: true }))
      }
    } else {
      const since = Date.parse(this.getAttribute("since"))
      if (Number.isNaN(since)) return
      this.textContent = reading(Math.max(0, Math.floor((now - since) / 1000)))
    }
  }
}

function reading(seconds) {
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`
  return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m ${seconds % 60}s`
}

customElements.get("unmagic-elapsed") || customElements.define("unmagic-elapsed", UnmagicElapsed)
