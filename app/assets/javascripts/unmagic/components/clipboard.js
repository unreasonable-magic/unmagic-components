// <unmagic-clipboard> — copies text when its button is clicked, rendered by
// `copy_button`.
//
//   value="…"  the text to copy
//   for="ID"   or copy, at the moment of the click, the value of that input or the
//              text of that element
//
// After a copy the element carries data-copied for a moment, which the CSS uses to
// swap the copy icon for a check, and its live region says "Copied" for a screen
// reader. It fires unmagic-clipboard:copy, or unmagic-clipboard:error when the
// browser refuses the write (no permission, or an insecure page).

const CONFIRM_FOR = 1500

class UnmagicClipboard extends HTMLElement {
  #timer = null

  constructor() {
    super()
    this.addEventListener("click", (event) => {
      if (event.target instanceof Element && event.target.closest("button")) this.copy()
    })
  }

  disconnectedCallback() {
    clearTimeout(this.#timer)
  }

  get text() {
    const id = this.getAttribute("for")
    if (!id) return this.getAttribute("value") ?? ""

    const source = document.getElementById(id)
    if (!source) return ""

    const control = source instanceof HTMLInputElement || source instanceof HTMLTextAreaElement || source instanceof HTMLSelectElement
    return control ? source.value : source.textContent
  }

  async copy() {
    const text = this.text

    try {
      await navigator.clipboard.writeText(text)
    } catch (error) {
      this.dispatchEvent(new CustomEvent("unmagic-clipboard:error", { bubbles: true, detail: { error } }))
      return
    }

    const live = this.querySelector(":scope > [aria-live]")
    this.setAttribute("data-copied", "")
    if (live) live.textContent = this.dataset.copiedLabel || "Copied"
    this.dispatchEvent(new CustomEvent("unmagic-clipboard:copy", { bubbles: true, detail: { text } }))

    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => {
      this.removeAttribute("data-copied")
      if (live) live.textContent = ""
    }, CONFIRM_FOR)
  }
}

customElements.get("unmagic-clipboard") || customElements.define("unmagic-clipboard", UnmagicClipboard)
