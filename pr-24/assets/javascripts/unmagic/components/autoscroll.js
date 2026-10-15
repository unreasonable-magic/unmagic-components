// <unmagic-autoscroll> — keeps a growing region pinned to the bottom while the
// reader is there, rendered by `ai_chat`.
//
// New content scrolls the page (or the scroller) to the bottom, but only while the
// reader is already within `threshold` pixels of it. Scroll up to re-read and
// nothing moves; scroll back down and following resumes. The reader's own
// scrolling is the only thing that decides.
//
//   threshold="32"      how near the bottom still counts as at it
//   scroller="#panel"   the scrolling box, found from the element outwards, then
//                       in the document; the page when absent
//
// A descendant [data-autoscroll-latest] button is shown while the reader is away
// from the bottom and takes them back when pressed. The element fires
// unmagic-autoscroll:pin and unmagic-autoscroll:unpin as that changes. It opens at
// the bottom, including when Turbo restores it from the cache. No Turbo needed.

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

class UnmagicAutoscroll extends HTMLElement {
  #pinned = true
  #frame = null
  #scroller = null
  #target = null
  #observer = new MutationObserver(() => this.#follow())

  constructor() {
    super()
    this.addEventListener("click", (event) => {
      if (event.target instanceof Element && event.target.closest("[data-autoscroll-latest]")) {
        this.scrollToBottom({ smooth: !reducedMotion.matches })
      }
    })
  }

  connectedCallback() {
    this.#scroller = this.#resolveScroller()
    this.#target = this.#scroller ?? window
    this.#target.addEventListener("scroll", this.#track, { passive: true })
    this.#observer.observe(this, { childList: true, subtree: true, characterData: true })
    this.#pinned = true
    this.#latest(false)
    this.scrollToBottom()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
    this.#target?.removeEventListener("scroll", this.#track)
    this.#target = null
    cancelAnimationFrame(this.#frame)
    this.#frame = null
  }

  get pinned() {
    return this.#pinned
  }

  scrollToBottom({ smooth = false } = {}) {
    const scrolling = this.#scrolling
    scrolling.scrollTo({ top: scrolling.scrollHeight, behavior: smooth ? "smooth" : "instant" })
  }

  get #scrolling() {
    return this.#scroller ?? document.scrollingElement
  }

  #resolveScroller() {
    const selector = this.getAttribute("scroller")
    if (!selector) return null
    return this.closest(selector) ?? document.querySelector(selector)
  }

  // A streamed reply changes the DOM many times a frame; scroll once per frame.
  #follow() {
    if (!this.#pinned || this.#frame) return

    this.#frame = requestAnimationFrame(() => {
      this.#frame = null
      if (this.#pinned) this.scrollToBottom()
    })
  }

  #track = () => {
    const { scrollTop, scrollHeight, clientHeight } = this.#scrolling
    const pinned = scrollHeight - clientHeight - scrollTop <= this.#threshold
    if (pinned === this.#pinned) return

    this.#pinned = pinned
    this.#latest(!pinned)
    this.dispatchEvent(new CustomEvent(`unmagic-autoscroll:${pinned ? "pin" : "unpin"}`, { bubbles: true }))
  }

  get #threshold() {
    const value = Number.parseInt(this.getAttribute("threshold"), 10)
    return Number.isNaN(value) ? 32 : value
  }

  #latest(show) {
    for (const button of this.querySelectorAll("[data-autoscroll-latest]")) button.hidden = !show
  }
}

customElements.get("unmagic-autoscroll") || customElements.define("unmagic-autoscroll", UnmagicAutoscroll)
