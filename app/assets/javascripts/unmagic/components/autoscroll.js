// <unmagic-autoscroll> — keeps a growing region pinned to the bottom while the
// reader is there, rendered by `ai_chat`.
//
// New content scrolls the page (or the scroller) to the bottom, but only while the
// reader is already within `threshold` pixels of it. Scroll up to re-read and
// nothing moves; scroll back down and following resumes. The reader's own
// scrolling decides, and two things that aren't it don't: the box changing height
// (a phone's keyboard opening, a rotation) keeps a pinned region at its new
// bottom, and a message the reader sends (an unmagic-optimistic insert into this
// element) takes them to it wherever they were.
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
  #height = 0
  #observer = new MutationObserver(() => this.#follow())
  #resize = new ResizeObserver(() => this.#resized())

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
    if (this.#scroller) this.#resize.observe(this.#scroller)
    else window.addEventListener("resize", this.#resized)
    document.addEventListener("unmagic-optimistic:insert", this.#sent)
    this.#height = this.#scrolling.clientHeight
    this.#pinned = true
    this.#latest(false)
    this.scrollToBottom()
  }

  disconnectedCallback() {
    this.#observer.disconnect()
    this.#resize.disconnect()
    window.removeEventListener("resize", this.#resized)
    document.removeEventListener("unmagic-optimistic:insert", this.#sent)
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
    // A scroll that came with a new height is the box resizing, not the reader.
    if (clientHeight !== this.#height) return this.#resized()

    this.#pin(scrollHeight - clientHeight - scrollTop <= this.#threshold)
  }

  // Shorter or taller (the keyboard, a rotation, a composer growing): a region
  // that was at the bottom stays there, rather than being left above it.
  #resized = () => {
    this.#height = this.#scrolling.clientHeight
    if (this.#pinned) this.scrollToBottom()
  }

  // The reader sent something into this region: show it to them.
  #sent = (event) => {
    if (!this.contains(event.detail?.element)) return

    this.#pin(true)
    this.scrollToBottom()
  }

  #pin(pinned) {
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
