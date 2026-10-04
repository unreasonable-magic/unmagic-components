// <unmagic-uuid-input name="message[id]"> — a hidden field holding a fresh UUIDv7,
// rendered by `uuid_field`.
//
// A form can then submit an id the client already knows, for instance to match an
// optimistically rendered element to the record the server goes on to create
// under the same id.
//
// A new id is minted when the element upgrades, replacing the server's fallback.
// That also covers a page Turbo restores from its cache, whose id may already have
// been used. Another is minted every time the form is reset, so a form that clears
// itself after each submit sends a new one next time.

class UnmagicUuidInput extends HTMLElement {
  #form = null

  connectedCallback() {
    this.#input.value = uuidv7()
    this.#form = this.closest("form")
    this.#form?.addEventListener("reset", this.#reset)
  }

  disconnectedCallback() {
    this.#form?.removeEventListener("reset", this.#reset)
    this.#form = null
  }

  get value() {
    return this.#input.value
  }

  // The server renders the input; one written by hand might not have.
  get #input() {
    let input = this.querySelector(":scope > input[type=hidden]")
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = this.getAttribute("name") || "id"
      this.append(input)
    }
    return input
  }

  // reset fires before the form resets its fields; mint on the microtask after,
  // once the reset can no longer touch the value.
  #reset = () => {
    queueMicrotask(() => {
      this.#input.value = uuidv7()
    })
  }
}

// A time-ordered UUIDv7: a 48-bit millisecond timestamp, then random bits. It sorts
// alongside the server's SecureRandom.uuid_v7 and can be used as a record's id.
export function uuidv7() {
  const bytes = new Uint8Array(16)
  crypto.getRandomValues(bytes)

  let time = Date.now()
  for (let i = 5; i >= 0; i--) {
    bytes[i] = time % 256
    time = Math.floor(time / 256)
  }
  bytes[6] = 0x70 | (bytes[6] & 0x0f) // version 7
  bytes[8] = 0x80 | (bytes[8] & 0x3f) // variant 10

  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

customElements.get("unmagic-uuid-input") || customElements.define("unmagic-uuid-input", UnmagicUuidInput)
