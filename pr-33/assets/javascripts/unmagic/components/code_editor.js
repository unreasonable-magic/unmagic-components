// <unmagic-code-editor language="json" schema="…"> — enhances code_editor_tag.
// The textarea is the form control and the fallback. Only this small registration
// loads globally; CodeMirror and each language load when an instance connects.
// value/focus/editor integrate with host JS. ready/change/error events bubble.
class UnmagicCodeEditor extends HTMLElement {
  #editor = null
  #generation = 0
  #form = null
  #observer = null
  #resetTimer = null

  constructor() {
    super()
    this.addEventListener("input", this.#input)
    this.addEventListener("invalid", this.#invalid, true)
    this.addEventListener("focus", (event) => { if (event.target === this.textarea && this.#editor) this.#editor.focus() }, true)
    this.addEventListener("turbo:before-morph-element", this.#beforeMorph)
  }

  get editor() { return this.#editor }
  get textarea() { return this.querySelector("textarea") }
  get value() { return this.textarea?.value || "" }
  set value(value) {
    if (!this.textarea) return
    this.textarea.value = value ?? ""
    this.#replace(this.textarea.value)
  }
  focus(options) { this.#editor ? this.#editor.focus() : this.textarea?.focus(options) }

  connectedCallback() {
    document.addEventListener("turbo:before-cache", this.#beforeCache)
    document.addEventListener("turbo:render", this.#render)
    document.addEventListener("turbo:morph", this.#render)
    this.#mount()
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.#beforeCache)
    document.removeEventListener("turbo:render", this.#render)
    document.removeEventListener("turbo:morph", this.#render)
    this.#destroy()
  }

  async #mount() {
    if (this.#editor || !this.isConnected) return
    const generation = ++this.#generation
    const textarea = this.textarea
    if (!textarea) return
    if (textarea.hasAttribute("data-editor-draft")) {
      textarea.value = textarea.getAttribute("data-editor-draft")
      textarea.removeAttribute("data-editor-draft")
    }
    this.querySelector("[data-editor-mount]").replaceChildren()
    this.removeAttribute("data-ready")
    try {
      const { createEditor } = await import("unmagic/components/code_editor/editor")
      const editor = await createEditor(this, textarea, () => this.#changed())
      if (generation !== this.#generation || !this.isConnected) {
        editor.destroy()
        return
      }
      this.#editor = editor
      const focused = document.activeElement === textarea
      textarea.dataset.editorTabindex = textarea.getAttribute("tabindex") ?? ""
      textarea.dataset.editorAriaHidden = textarea.getAttribute("aria-hidden") ?? ""
      textarea.setAttribute("tabindex", "-1")
      textarea.setAttribute("aria-hidden", "true")
      this.setAttribute("data-ready", "")
      this.querySelector("[data-editor-status]").textContent = ""
      this.#form = textarea.form
      this.#form?.addEventListener("reset", this.#reset)
      this.#observer = new MutationObserver(() => {
        this.#destroy()
        this.#mount()
      })
      this.#observer.observe(textarea, { attributes: true, attributeFilter: ["disabled", "readonly", "aria-invalid", "aria-describedby", "aria-label", "aria-labelledby"] })
      if (focused) this.focus()
      this.dispatchEvent(new CustomEvent("unmagic-code-editor:ready", { bubbles: true }))
    } catch (error) {
      if (generation !== this.#generation) return
      this.querySelector("[data-editor-mount]").replaceChildren()
      const status = this.querySelector("[data-editor-status]")
      status.textContent = status.dataset.errorMessage
      this.dispatchEvent(new CustomEvent("unmagic-code-editor:error", { bubbles: true, detail: { error } }))
    }
  }

  #changed() {
    if (!this.#editor) return
    this.textarea.value = this.#editor.state.doc.toString()
    this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
    this.textarea.dispatchEvent(new Event("change", { bubbles: true }))
    this.dispatchEvent(new CustomEvent("unmagic-code-editor:change", { bubbles: true, detail: { value: this.value } }))
  }

  #replace(value) {
    if (this.#editor && this.#editor.state.doc.toString() !== value)
      this.#editor.dispatch({ changes: { from: 0, to: this.#editor.state.doc.length, insert: value } })
  }

  #input = (event) => {
    if (event.target === this.textarea) this.#replace(this.textarea.value)
  }
  #invalid = (event) => {
    if (event.target === this.textarea && this.#editor) {
      event.preventDefault()
      this.focus()
    }
  }
  #reset = (event) => {
    clearTimeout(this.#resetTimer)
    this.#resetTimer = setTimeout(() => {
      if (!event.defaultPrevented && this.isConnected) this.#replace(this.textarea.value)
    })
  }
  #beforeCache = () => this.#destroy()
  #beforeMorph = (event) => {
    if (event.target === this) this.#destroy()
  }
  #render = () => this.#mount()

  #destroy() {
    ++this.#generation
    clearTimeout(this.#resetTimer)
    this.#observer?.disconnect()
    this.#form?.removeEventListener("reset", this.#reset)
    if (this.#editor) {
      this.textarea.value = this.#editor.state.doc.toString()
      this.textarea.setAttribute("data-editor-draft", this.textarea.value)
      this.#editor.destroy()
      this.#editor = null
      for (const [attribute, key] of [["tabindex", "editorTabindex"], ["aria-hidden", "editorAriaHidden"]]) {
        const value = this.textarea.dataset[key]
        if (value) this.textarea.setAttribute(attribute, value)
        else this.textarea.removeAttribute(attribute)
        delete this.textarea.dataset[key]
      }
    }
    this.removeAttribute("data-ready")
  }
}

customElements.get("unmagic-code-editor") || customElements.define("unmagic-code-editor", UnmagicCodeEditor)
