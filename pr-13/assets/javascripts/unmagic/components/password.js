// <unmagic-password> — a password input with a button that shows what was
// typed, rendered by password_field(reveal: true).
//
// The button renders hidden and is shown here, so without script there is a
// working password field and no dead button. It is always called "Show password",
// with aria-pressed while revealed. Toggling keeps the input's selection.

class UnmagicPassword extends HTMLElement {
  connectedCallback() {
    const button = this.querySelector(":scope > button")
    if (button) button.hidden = false
    this.addEventListener("click", this.#clicked)
  }

  disconnectedCallback() {
    this.removeEventListener("click", this.#clicked)
  }

  #clicked = (event) => {
    const button = event.target instanceof Element && event.target.closest("button")
    const input = this.querySelector("input")
    if (!button || !input) return

    const revealed = input.type === "password"
    const { selectionStart, selectionEnd } = input
    input.type = revealed ? "text" : "password"
    button.setAttribute("aria-pressed", String(revealed))
    try {
      input.setSelectionRange(selectionStart, selectionEnd)
    } catch {
      // Some inputs refuse a selection; the caret just moves to the end.
    }
  }
}

customElements.get("unmagic-password") || customElements.define("unmagic-password", UnmagicPassword)
