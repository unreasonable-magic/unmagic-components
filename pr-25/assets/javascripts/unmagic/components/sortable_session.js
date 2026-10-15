// The drag engine behind <unmagic-sortable-list> and <unmagic-sortable-item>, by
// pointer or by keyboard. One drag at a time.
//
// By pointer it floats a copy of the item under the cursor while the item itself
// moves through the lists as a live preview of where it will land: into whichever
// list under the pointer accepts it, at the slot the pointer is in (vertical lists
// and wrapping rows alike). Near the edge of anything scrollable, including the
// page, it scrolls. Escape puts the item back. On release, the list it landed in
// posts the move.
//
// On a touch screen, a finger is usually scrolling, so unless it's on a handle
// that stops scrolling (a grip) the item waits for a long press (LONG_PRESS,
// holding within TOUCH_SLOP) before it lifts. Moving sooner is a scroll and
// nothing is dragged; lifting sooner is a tap and reaches whatever was tapped.
// Once lifted, the page stops scrolling under the finger for the rest of the
// gesture.
//
// By keyboard, Space or Enter on an item's handle (or the item, when it has none)
// picks it up. The arrow keys along the list move it within the list; the arrows
// across it move it to the neighbouring list that accepts it. Space or Enter drops
// it, and Escape or leaving it puts it back. Every step is announced.
//
// The engine uses the elements only through their public methods and properties
// (item.list, list.accepts, list.items, list.submit), so nothing imports it back.
//
// State is data attributes, which the CSS and the sortable-* Tailwind variants key
// on: data-sortable-dragging on the floating copy, data-sortable-placeholder on the
// item while a pointer drags it, data-sortable-lifted while a keyboard holds it,
// data-sortable-active on every list that can take it, and data-sortable-over on
// the list under the pointer.

const THRESHOLD = 4 // pixels of movement before a press becomes a drag
const LONG_PRESS = 250 // milliseconds a finger holds still before an item lifts
const TOUCH_SLOP = 8 // pixels a finger may drift during that hold
const EDGE = 56 // pixels from a scroller's edge where dragging scrolls it
const MAX_SPEED = 20 // pixels a frame at the very edge

const LIST = "unmagic-sortable-list"
const DRAGGING = "data-sortable-dragging"
const PLACEHOLDER = "data-sortable-placeholder"
const LIFTED = "data-sortable-lifted"
const ACTIVE = "data-sortable-active"
const OVER = "data-sortable-over"

let active = null

export function dragging() {
  return active !== null
}

export function beginPointerDrag(item, event, { immediate = false } = {}) {
  if (!active) active = new PointerDrag(item, event, immediate)
}

export function beginKeyboardDrag(item, stop) {
  if (!active) active = new KeyboardDrag(item, stop)
}

export function keyboardDragOf(item) {
  return active instanceof KeyboardDrag && active.item === item ? active : null
}

// Put a list's item where `before` is, or at the end of its items when null, which
// keeps it ahead of anything marked data-sortable-tail (an "add" tile).
export function place(list, item, before) {
  if (before) {
    before.before(item)
  } else {
    const tail = list.tail()
    if (tail) tail.before(item)
    else list.append(item)
  }
}

class Drag {
  constructor(item) {
    this.item = item
    this.origin = item.list
    this.startParent = item.parentElement
    this.startNext = item.nextElementSibling
    this.targets = []
    // A subclass's cancel isn't assigned until this constructor returns, so the
    // listener calls through to whichever cancel the drag ends up with.
    this.cacheListener = () => this.cancel()
    document.addEventListener("turbo:before-cache", this.cacheListener)
  }

  // Every list that can take the item: its own, and any sharing its namespace.
  lightUp() {
    this.targets = [...document.querySelectorAll(LIST)].filter((list) => list.accepts(this.origin))
    for (const list of this.targets) list.setAttribute(ACTIVE, "")
  }

  end() {
    for (const list of this.targets) {
      list.removeAttribute(ACTIVE)
      list.removeAttribute(OVER)
    }
    document.removeEventListener("turbo:before-cache", this.cacheListener)
    active = null
  }

  moved() {
    return this.item.parentElement !== this.startParent || this.item.nextElementSibling !== this.startNext
  }

  restore() {
    this.startParent.insertBefore(this.item, this.startNext)
  }

  commit() {
    if (this.moved()) this.item.list?.submit(this.item)
  }
}

class PointerDrag extends Drag {
  #pointerId
  #offsetX
  #offsetY
  #width
  #startX
  #startY
  #x
  #y
  #started = false
  #clone = null
  #frame = null
  #touch = false
  #press = null

  constructor(item, event, immediate) {
    super(item)
    this.#pointerId = event.pointerId
    this.#touch = event.pointerType === "touch" && !immediate

    const box = item.getBoundingClientRect()
    this.#offsetX = event.clientX - box.left
    this.#offsetY = event.clientY - box.top
    this.#width = box.width
    this.#startX = this.#x = event.clientX
    this.#startY = this.#y = event.clientY

    // A touch that may yet be a scroll isn't captured, so the browser can pan.
    if (!this.#touch) item.setPointerCapture?.(event.pointerId)
    window.addEventListener("pointermove", this.#move)
    window.addEventListener("pointerup", this.#up)
    window.addEventListener("pointercancel", this.cancel)
    window.addEventListener("keydown", this.#keydown)

    if (this.#touch) {
      // Non-passive, so it can stop the page scrolling once the item has lifted. It
      // does nothing before then, so a scroll is still a scroll.
      window.addEventListener("touchmove", this.#holdPage, { passive: false })
      window.addEventListener("contextmenu", this.#noMenu)
      this.#press = setTimeout(this.#lift, LONG_PRESS)
    }

    if (immediate) {
      event.preventDefault()
      this.#start()
      this.#follow()
    }
  }

  #move = (event) => {
    if (event.pointerId !== this.#pointerId) return
    this.#x = event.clientX
    this.#y = event.clientY

    if (!this.#started) {
      const distance = Math.hypot(this.#x - this.#startX, this.#y - this.#startY)
      if (this.#touch) {
        if (distance > TOUCH_SLOP) this.#stop() // moved before the hold: a scroll
        return
      }
      if (distance < THRESHOLD) return
      this.#start()
    }

    event.preventDefault()
    this.#follow()
    this.#reposition()
  }

  // The copy is made before anything else is marked, so its own lists aren't
  // mistaken for targets, and it is inert and stripped of ids so it can't be.
  #start() {
    this.#started = true
    this.lightUp()

    const clone = this.item.cloneNode(true)
    clone.setAttribute(DRAGGING, "")
    clone.setAttribute("aria-hidden", "true")
    clone.inert = true
    clone.removeAttribute("id")
    for (const element of clone.querySelectorAll("[id]")) element.removeAttribute("id")
    clone.style.width = `${this.#width}px`
    document.body.append(clone)
    this.#clone = clone

    this.item.setAttribute(PLACEHOLDER, "")
    this.#frame = requestAnimationFrame(this.#scroll)
  }

  // The long press held: lift the item where the finger is, and take the pointer.
  #lift = () => {
    this.#press = null
    if (active !== this || this.#started) return

    this.item.setPointerCapture?.(this.#pointerId)
    navigator.vibrate?.(10)
    this.#start()
    this.#follow()
  }

  #holdPage = (event) => {
    if (this.#started && event.cancelable) event.preventDefault()
  }

  #noMenu = (event) => {
    event.preventDefault()
  }

  #follow() {
    this.#clone.style.transform = `translate(${this.#x - this.#offsetX}px, ${this.#y - this.#offsetY}px)`
  }

  #reposition() {
    const list = this.#listAt(this.#x, this.#y)
    for (const target of this.targets) target.toggleAttribute(OVER, target === list)
    if (list) place(list, this.item, slotBefore(list, this.item, this.#x, this.#y))
  }

  // The innermost list under the pointer that takes this item. A column dragged
  // over a column's cards passes the cards' list by for the board's.
  #listAt(x, y) {
    let list = document.elementFromPoint(x, y)?.closest(LIST)
    while (list) {
      if (list.accepts(this.origin) && !this.item.contains(list)) return list
      list = list.parentElement?.closest(LIST)
    }
    return null
  }

  #scroll = () => {
    this.#frame = null
    if (!active || active !== this) return

    let scrolled = false
    for (const scroller of scrollersAt(this.#x, this.#y)) {
      const page = scroller === document.scrollingElement
      const box = page ? { left: 0, top: 0, right: innerWidth, bottom: innerHeight } : scroller.getBoundingClientRect()
      const dx = scroller.scrollWidth > scroller.clientWidth ? speed(this.#x, box.left, box.right) : 0
      const dy = scroller.scrollHeight > scroller.clientHeight ? speed(this.#y, box.top, box.bottom) : 0
      if (!dx && !dy) continue

      const beforeLeft = scroller.scrollLeft
      const beforeTop = scroller.scrollTop
      scroller.scrollLeft += dx
      scroller.scrollTop += dy
      scrolled ||= scroller.scrollLeft !== beforeLeft || scroller.scrollTop !== beforeTop
    }

    if (scrolled) this.#reposition()
    this.#frame = requestAnimationFrame(this.#scroll)
  }

  #keydown = (event) => {
    if (event.key !== "Escape" || !this.#started) return
    event.preventDefault()
    this.cancel()
  }

  #up = (event) => {
    if (event.pointerId !== this.#pointerId) return
    const started = this.#started
    this.#stop()
    if (!started) return

    suppressNextClick()
    this.commit()
  }

  cancel = (event) => {
    if (event?.pointerId !== undefined && event.pointerId !== this.#pointerId) return
    const started = this.#started
    this.#stop()
    if (started) this.restore()
  }

  #stop() {
    clearTimeout(this.#press)
    this.#press = null
    window.removeEventListener("touchmove", this.#holdPage)
    window.removeEventListener("contextmenu", this.#noMenu)
    window.removeEventListener("pointermove", this.#move)
    window.removeEventListener("pointerup", this.#up)
    window.removeEventListener("pointercancel", this.cancel)
    window.removeEventListener("keydown", this.#keydown)
    if (this.#frame) cancelAnimationFrame(this.#frame)
    this.#frame = null
    this.#clone?.remove()
    this.item.removeAttribute(PLACEHOLDER)
    this.end()
  }
}

class KeyboardDrag extends Drag {
  #stop
  #moving = false

  constructor(item, stop) {
    super(item)
    this.#stop = stop
    this.lightUp()
    item.setAttribute(LIFTED, "")
    stop.addEventListener("blur", this.#blur)
    announce(item, "picked")
  }

  // Keys while holding the item. Handled here and nowhere else: an outer item
  // mustn't act on them too.
  key(event) {
    const list = this.item.list
    const orientation = list?.orientation || "vertical"
    const along = ALONG[orientation][event.key]
    const across = ACROSS[orientation][event.key]

    if (event.key === " " || event.key === "Enter") this.drop()
    else if (event.key === "Escape") this.cancel()
    else if (along) this.#step(along)
    else if (across) this.#jump(across)
    else return

    event.preventDefault()
    event.stopPropagation()
  }

  #step(delta) {
    const items = this.item.list.items()
    const neighbour = items[items.indexOf(this.item) + delta]
    if (!neighbour) return

    this.#moveTo(() => (delta < 0 ? neighbour.before(this.item) : neighbour.after(this.item)))
  }

  // To the same position in the next list along, or its end.
  #jump(delta) {
    const lists = this.targets.filter((list) => !this.item.contains(list))
    const next = lists[lists.indexOf(this.item.list) + delta]
    if (!next) return

    const index = this.item.list.items().indexOf(this.item)
    this.#moveTo(() => place(next, this.item, next.itemsExcept(this.item)[index] ?? null))
  }

  // Moving a focused element can drop its focus, so it's handed straight back.
  #moveTo(move) {
    this.#moving = true
    move()
    this.#stop.focus()
    this.#moving = false
    this.item.scrollIntoView({ block: "nearest", inline: "nearest" })
    announce(this.item, "moved")
  }

  drop() {
    this.#finish()
    announce(this.item, "dropped")
    this.commit()
  }

  cancel = () => {
    this.#moving = true
    this.restore()
    this.#stop.focus()
    this.#moving = false
    this.#finish()
    announce(this.item, "cancelled")
  }

  #blur = () => {
    if (this.#moving) return
    setTimeout(() => {
      if (active === this && document.activeElement !== this.#stop) this.cancel()
    })
  }

  #finish() {
    this.#stop.removeEventListener("blur", this.#blur)
    this.item.removeAttribute(LIFTED)
    this.end()
  }
}

// Which arrow moves an item along its list, and which moves it across to the next
// list, for each orientation.
const ALONG = {
  vertical: { ArrowUp: -1, ArrowDown: 1 },
  horizontal: { ArrowLeft: -1, ArrowRight: 1 },
  grid: { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -1, ArrowDown: 1 },
}
const ACROSS = {
  vertical: { ArrowLeft: -1, ArrowRight: 1 },
  horizontal: { ArrowUp: -1, ArrowDown: 1 },
  grid: {},
}

// The item the dragged one should sit before, or null for the end. It finds the
// item whose centre is nearest the pointer and picks a side: in a wrapping row, a
// row above means before and the same row goes by the centre line; in a list of
// full-width items, above the centre means before.
function slotBefore(list, dragged, x, y) {
  const others = list.itemsExcept(dragged)
  if (others.length === 0) return null

  let nearest = null
  let distance = Infinity
  for (const item of others) {
    const box = item.getBoundingClientRect()
    const centreX = box.left + box.width / 2
    const centreY = box.top + box.height / 2
    const d = Math.hypot(x - centreX, y - centreY)
    if (d < distance) {
      distance = d
      nearest = { item, box, centreX, centreY }
    }
  }

  const across = nearest.box.width < list.getBoundingClientRect().width - 4
  let after
  if (across) {
    if (y < nearest.box.top) after = false
    else if (y > nearest.box.bottom) after = true
    else after = x > nearest.centreX
  } else {
    after = y > nearest.centreY
  }

  if (!after) return nearest.item
  return others[others.indexOf(nearest.item) + 1] ?? null
}

// Everything under a point that scrolls, innermost first, and the page.
function scrollersAt(x, y) {
  const found = []
  for (let element = document.elementFromPoint(x, y); element; element = element.parentElement) {
    if (element === document.body || element === document.documentElement) break
    const style = getComputedStyle(element)
    const scrolls = /(auto|scroll)/.test(style.overflowX + style.overflowY)
    if (scrolls && (element.scrollWidth > element.clientWidth || element.scrollHeight > element.clientHeight)) {
      found.push(element)
    }
  }
  found.push(document.scrollingElement)
  return found
}

// How far to scroll this frame: faster the nearer the pointer is to an edge, and
// as fast as it goes past one.
function speed(position, start, end) {
  if (position < start + EDGE) return -Math.round(MAX_SPEED * Math.min(1, (start + EDGE - position) / EDGE))
  if (position > end - EDGE) return Math.round(MAX_SPEED * Math.min(1, (position - (end - EDGE)) / EDGE))
  return 0
}

// A drag ends with a click on whatever is under the pointer; swallow it so a drag
// off a linked card doesn't also follow the link.
function suppressNextClick() {
  const swallow = (event) => {
    event.stopPropagation()
    event.preventDefault()
  }
  window.addEventListener("click", swallow, { capture: true, once: true })
  setTimeout(() => window.removeEventListener("click", swallow, { capture: true }), 0)
}

function announce(item, key) {
  const list = item.list
  const template = list?.dataset[`sortable${key[0].toUpperCase()}${key.slice(1)}`]
  if (!template) return

  const items = list.items()
  const text = template
    .replaceAll("{item}", item.label)
    .replaceAll("{list}", list.label)
    .replaceAll("{position}", String(items.indexOf(item) + 1))
    .replaceAll("{count}", String(items.length))

  let region = document.querySelector("[data-unmagic-sortable-live]")
  if (!region) {
    region = document.createElement("div")
    region.setAttribute("data-unmagic-sortable-live", "")
    region.setAttribute("aria-live", "assertive")
    region.className = "UnmagicVisuallyHidden"
    document.body.append(region)
  }
  region.textContent = ""
  requestAnimationFrame(() => {
    region.textContent = text
  })
}
