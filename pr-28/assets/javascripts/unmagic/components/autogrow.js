// <unmagic-autogrow> — a textarea that grows to fit what's typed, rendered by
// `autogrow_text_area`.
//
// It grows from the height its rows give it up to its CSS max-height, and only
// then shows a scrollbar. CSS `field-sizing: content` would do the growing on its
// own, but it ignores rows, so an empty box would collapse to a single line;
// measuring keeps rows as the floor.
//
// It re-measures as you type, when the form is reset, and when the box changes
// width (a narrower box wraps onto more lines). Call resize() after setting the
// value from script.

class UnmagicAutogrow extends HTMLElement {
  #form = null
  #width = 0
  #observer = new ResizeObserver(([entry]) => {
    const width = Math.round(entry.contentRect.width)
    if (width === this.#width) return
    this.#width = width
    this.resize()
  })

  constructor() {
    super()
    this.addEventListener("input", (event) => {
      if (event.target === this.textarea) this.resize()
    })
  }

  connectedCallback() {
    this.resize()
    this.#observer.observe(this)
    this.#form = this.textarea?.form ?? null
    this.#form?.addEventListener("reset", this.#reset)
  }

  disconnectedCallback() {
    this.#observer.disconnect()
    this.#form?.removeEventListener("reset", this.#reset)
    this.#form = null
  }

  get textarea() {
    return this.querySelector("textarea")
  }

  resize() {
    const textarea = this.textarea
    if (!textarea) return

    // Collapse to the rows-given height first, so the measurement can shrink too.
    textarea.style.height = "auto"

    const style = getComputedStyle(textarea)
    const sum = (a, b) => parseFloat(style[a]) + parseFloat(style[b])

    // scrollHeight is the content plus padding. The height to set is in the box's
    // own sizing model, which max-height is in too.
    const full = style.boxSizing === "border-box"
      ? textarea.scrollHeight + sum("borderTopWidth", "borderBottomWidth")
      : textarea.scrollHeight - sum("paddingTop", "paddingBottom")
    const max = parseFloat(style.maxHeight) || Infinity

    textarea.style.height = `${Math.min(full, max)}px`
    textarea.style.overflowY = full > max ? "auto" : "hidden"
  }

  // reset fires before the form clears its fields, so measure on the next frame.
  #reset = () => {
    requestAnimationFrame(() => this.resize())
  }
}

customElements.get("unmagic-autogrow") || customElements.define("unmagic-autogrow", UnmagicAutogrow)
