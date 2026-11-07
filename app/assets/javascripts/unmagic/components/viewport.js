// <unmagic-viewport> — a full-screen app's frame that stays on screen when the
// on-screen keyboard opens, rendered by `viewport_tag`.
//
// A phone's keyboard shrinks the visual viewport and leaves the page's alone, so
// iOS Safari slides a 100dvh page up to show the focused field, and the header
// goes off the top. The frame is fixed instead, and this keeps it over the visual
// viewport: as tall as what's above the keyboard, moved down by however far
// Safari has panned. Its content scrolls inside it; the document never does.
//
// The two numbers go on <html> as --unmagic-viewport-height and
// --unmagic-viewport-offset, where a Turbo morph (which rewrites the frame's own
// attributes) leaves them. While the page is pinch-zoomed nothing changes:
// zooming is someone looking closer, not the room getting smaller.

class UnmagicViewport extends HTMLElement {
  connectedCallback() {
    const viewport = window.visualViewport
    if (!viewport) return

    viewport.addEventListener("resize", this.#update)
    viewport.addEventListener("scroll", this.#update)
    this.#update()
  }

  disconnectedCallback() {
    window.visualViewport?.removeEventListener("resize", this.#update)
    window.visualViewport?.removeEventListener("scroll", this.#update)
  }

  #update = () => {
    const { height, offsetTop, scale } = window.visualViewport
    if (Math.abs(scale - 1) > 0.01) return

    const root = document.documentElement.style
    root.setProperty("--unmagic-viewport-height", `${height}px`)
    root.setProperty("--unmagic-viewport-offset", `${offsetTop}px`)
  }
}

customElements.get("unmagic-viewport") || customElements.define("unmagic-viewport", UnmagicViewport)
