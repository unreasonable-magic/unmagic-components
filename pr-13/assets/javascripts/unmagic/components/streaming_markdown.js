// <unmagic-streaming-markdown id="…_content"> — server-rendered HTML revealed at a
// steady pace as fuller renders arrive, rendered by `streaming_markdown_tag` and
// `ai_chat_message`.
//
// The server renders a reply to HTML and sends the whole render on every flush,
// through the `stream_markdown` Turbo Stream action registered below. Flushes
// arrive in bursts, which paints chunkily; this element decouples reveal cadence
// from arrival. It holds the newest render as a target and eases a character
// cursor toward it every animation frame. Parsing stays on the server: this only
// reveals a growing prefix of the HTML.
//
// It reveals at a constant velocity — the model's own average production rate —
// and lets the buffer (how far the cursor trails the live edge) absorb the bursts.
// A proportional "close a fraction of the gap" scheme would speed up and slow down
// on every burst. The rate is an average over RATE_SMOOTHING; a soft pull toward a
// small buffer (BUFFER_SECONDS) stops the trailing distance drifting; a lag cap
// catches up on a big jump (a reconnect) and a trickle floor finishes the tail.
//
// The visible prefix is reconciled block by block: settled leading blocks
// (identical by tag and text) are left alone, and everything from the first
// changed block is rebuilt, which keeps lists and tables structurally intact.
//
// When the settled turn replaces the streaming one mid-reveal, the replacement
// picks up where the old element left off (HANDOFF) and paces to the end, but only
// if its content extends what was on screen; a divergent settle (a "stopped" note)
// shows at once.
//
//   final       settled: show the content as it is and refuse any later flush.
//               This is what lets a Stop button's optimistic swap stick before
//               the server has settled the turn.
//   aria-busy   rendered while a reply is live; removed once the reveal has
//               caught up and gone quiet, so a live region announces the reply
//               once rather than on every flush.
//
// It fires unmagic-streaming-markdown:settle when it catches up. Under reduced
// motion every flush paints in full. Needs Turbo.
import { Turbo } from "@hotwired/turbo-rails"

const RATE_SMOOTHING = 0.6 // seconds: the window for the production-rate average, which is the reveal speed
const BUFFER_SECONDS = 0.3 // seconds of text the cursor aims to keep between itself and the live edge
const SOFTNESS = 0.4 // per second: how firmly that buffer is held; smaller is steadier and drifts more
const MAX_LAG_SECONDS = 1.5 // always drain the whole backlog within this long
const MIN_TRICKLE = 24 // characters a second, so the tail still finishes
const IDLE_MS = 700 // keep the loop alive this long after the last flush
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

// Reveal progress carried across an element swap, keyed by element id.
const HANDOFF = new Map()

class UnmagicStreamingMarkdown extends HTMLElement {
  #target = null // DocumentFragment: the newest full render
  #targetLength = 0 // its revealable length (the sum of top-level block text)
  #revealed = 0 // characters on screen, fractional between frames
  #rate = 0 // estimated production rate in characters a second
  #lastArrival = 0
  #lastFrame = 0
  #frame = null
  #frozen = false

  connectedCallback() {
    if (this.hasAttribute("final")) {
      HANDOFF.delete(this.id)
      this.#frozen = true
      this.#revealed = blockLength(this)
      return
    }

    const handoff = HANDOFF.get(this.id)
    HANDOFF.delete(this.id)
    const full = blockLength(this)
    const continues =
      handoff && handoff.revealed > 0 && handoff.revealed < full && this.textContent.startsWith(handoff.text)

    if (continues && !reducedMotion.matches) {
      this.#target = adoptChildren(this)
      this.#targetLength = full
      this.#revealed = handoff.revealed
      this.#rate = handoff.rate
      this.#lastArrival = performance.now()
      this.#paint()
      this.#schedule()
    } else {
      this.#revealed = full
      this.#targetLength = full
    }
  }

  disconnectedCallback() {
    if (this.#frame) cancelAnimationFrame(this.#frame)
    this.#frame = null

    if (this.#revealed < this.#targetLength) {
      HANDOFF.set(this.id, { revealed: this.#revealed, rate: this.#rate, text: this.textContent })
    } else {
      HANDOFF.delete(this.id)
    }
  }

  // Called by the stream_markdown action with a fragment of the whole render so far.
  streamUpdate(fragment) {
    if (this.#frozen) return

    const now = performance.now()
    const length = blockLength(fragment)
    const grew = Math.max(0, length - this.#targetLength)
    this.#target = fragment
    this.#targetLength = length
    if (this.#revealed > length) this.#revealed = length

    this.#observeRate(now, grew)
    this.#lastArrival = now
    this.setAttribute("aria-busy", "true")

    if (reducedMotion.matches) {
      this.#revealed = length
      this.#paint()
      this.#settle()
    } else {
      this.#paint()
      this.#schedule()
    }
  }

  // Lock onto the first reading, so the opening characters don't crawl while the
  // average warms up.
  #observeRate(now, grew) {
    if (!this.#lastArrival) return

    const dt = (now - this.#lastArrival) / 1000
    if (dt <= 0) return

    const instant = grew / dt
    if (this.#rate === 0) this.#rate = instant
    else this.#rate += (1 - Math.exp(-dt / RATE_SMOOTHING)) * (instant - this.#rate)
  }

  #schedule() {
    if (this.#frame) return
    this.#lastFrame = performance.now()
    this.#frame = requestAnimationFrame((now) => this.#tick(now))
  }

  #tick(now) {
    this.#frame = null
    const dt = Math.min(0.05, (now - this.#lastFrame) / 1000) // a backgrounded tab resumes gently
    this.#lastFrame = now

    const backlog = this.#targetLength - this.#revealed
    if (backlog > 0) {
      let velocity = this.#rate + (backlog - this.#rate * BUFFER_SECONDS) * SOFTNESS
      velocity = Math.max(velocity, backlog / MAX_LAG_SECONDS)
      velocity = Math.min(2000, Math.max(MIN_TRICKLE, velocity))
      this.#revealed = Math.min(this.#targetLength, this.#revealed + velocity * dt)
      if (this.#targetLength - this.#revealed < 0.5) this.#revealed = this.#targetLength
      this.#paint()
    }

    const streaming = now - this.#lastArrival < IDLE_MS
    if (this.#revealed < this.#targetLength || streaming) this.#schedule()
    else this.#settle()
  }

  #settle() {
    if (!this.hasAttribute("aria-busy")) return
    this.removeAttribute("aria-busy")
    this.dispatchEvent(new CustomEvent("unmagic-streaming-markdown:settle", { bubbles: true }))
  }

  #paint() {
    const visible = truncatedClone(this.#target, Math.floor(this.#revealed))
    try {
      this.#reconcile(visible)
    } catch {
      this.replaceChildren(visible)
    }
  }

  #reconcile(fragment) {
    const incoming = Array.from(fragment.children)
    if (incoming.length === 0) return this.replaceChildren(fragment)

    const current = Array.from(this.children)
    let i = 0
    while (
      i < current.length &&
      i < incoming.length &&
      current[i].nodeName === incoming[i].nodeName &&
      current[i].textContent === incoming[i].textContent
    )
      i++

    if (i === 0) {
      this.replaceChildren()
    } else {
      const anchor = current[i - 1]
      while (anchor.nextSibling) anchor.nextSibling.remove()
    }
    for (let k = i; k < incoming.length; k++) this.append(incoming[k])
  }
}

customElements.get("unmagic-streaming-markdown") ||
  customElements.define("unmagic-streaming-markdown", UnmagicStreamingMarkdown)

// Move an element's children into a fragment, leaving it empty to reveal into.
function adoptChildren(root) {
  const fragment = document.createDocumentFragment()
  while (root.firstChild) fragment.append(root.firstChild)
  return fragment
}

// A clone of the target's top-level blocks, cut to `limit` characters of block
// text; the last block is split where the cursor lands inside it.
function truncatedClone(target, limit) {
  const fragment = document.createDocumentFragment()
  if (!target) return fragment

  let count = 0
  for (const child of target.children) {
    if (count >= limit) break
    const length = child.textContent.length
    const clone = child.cloneNode(true)
    if (count + length <= limit) {
      fragment.append(clone)
      count += length
    } else {
      truncateTo(clone, limit - count)
      fragment.append(clone)
      break
    }
  }
  return fragment
}

// The text length of an element's top-level blocks. Whitespace between blocks
// doesn't count.
function blockLength(root) {
  let length = 0
  for (const child of root.children) length += child.textContent.length
  return length
}

function truncateTo(root, limit) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
  let count = 0
  let lastKept = null
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    const length = node.data.length
    if (count + length <= limit) {
      count += length
      lastKept = node
      if (count === limit) break
    } else {
      node.data = node.data.slice(0, limit - count)
      lastKept = node
      break
    }
  }
  if (!lastKept) return root.replaceChildren()
  for (let node = lastKept; node && node !== root; node = node.parentNode) {
    while (node.nextSibling) node.nextSibling.remove()
  }
}

// `update`, for streamed Markdown: hand the whole render to the element, which
// paces its way to it.
Turbo.StreamActions.stream_markdown = function () {
  for (const element of this.targetElements) element.streamUpdate?.(this.templateContent)
}
