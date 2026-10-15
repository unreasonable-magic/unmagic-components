// <unmagic-one-time-code> — one input for a code, drawn as a row of boxes,
// rendered by one_time_code_field.
//
//   length="6"           how many boxes
//   charset="numeric"    or "alphanumeric": anything else typed is dropped
//   submit               submit the form once the last character is in
//
// The input stays a single real input over the boxes, so typing, Backspace,
// arrows, paste and autofill are all native; this only draws. It never submits
// on connect with a pre-filled value, only after a real edit reaches full length.

class UnmagicOneTimeCode extends HTMLElement {
  #cells = []

  connectedCallback() {
    const input = this.input
    if (!input) return

    this.#draw()
    input.addEventListener("input", this.#changed)
    input.addEventListener("keyup", this.#moved)
    input.addEventListener("click", this.#moved)
    input.addEventListener("focus", this.#moved)
    input.addEventListener("blur", this.#moved)
    this.#paint()
  }

  disconnectedCallback() {
    const input = this.input
    if (!input) return
    input.removeEventListener("input", this.#changed)
    input.removeEventListener("keyup", this.#moved)
    input.removeEventListener("click", this.#moved)
    input.removeEventListener("focus", this.#moved)
    input.removeEventListener("blur", this.#moved)
  }

  get input() {
    return this.querySelector("input")
  }

  get length() {
    return Number(this.getAttribute("length")) || 6
  }

  #draw() {
    let cells = this.querySelector(":scope > .UnmagicOneTimeCode__cells")
    if (!cells) {
      cells = document.createElement("div")
      cells.className = "UnmagicOneTimeCode__cells"
      cells.setAttribute("aria-hidden", "true")
      for (let i = 0; i < this.length; i++) {
        const cell = document.createElement("span")
        cell.className = "UnmagicOneTimeCode__cell"
        cells.append(cell)
      }
      this.append(cells)
    }
    this.#cells = [...cells.children]
    this.setAttribute("data-upgraded", "")
  }

  #changed = () => {
    const input = this.input
    const allowed = this.getAttribute("charset") === "alphanumeric" ? /[^a-z0-9]/gi : /\D/g
    const clean = input.value.replace(allowed, "").slice(0, this.length)
    if (clean !== input.value) input.value = clean
    this.#paint()

    if (this.hasAttribute("submit") && clean.length === this.length && input.form) {
      input.form.requestSubmit()
    }
  }

  #moved = () => this.#paint()

  #paint() {
    const input = this.input
    const value = input.value
    const focused = document.activeElement === input
    const caret = Math.min(input.selectionStart ?? value.length, this.length - 1)

    this.#cells.forEach((cell, index) => {
      cell.textContent = value[index] ?? ""
      cell.toggleAttribute("data-filled", index < value.length)
      cell.toggleAttribute("data-active", focused && index === Math.min(caret, value.length, this.length - 1))
    })
  }
}

customElements.get("unmagic-one-time-code") || customElements.define("unmagic-one-time-code", UnmagicOneTimeCode)
