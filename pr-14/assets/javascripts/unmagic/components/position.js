// Places a floating panel beside an anchor. A module, not an element: tooltip,
// menu, popover and context menu all float something, and this is the one
// place that decides where it goes.
//
//   place(panel, anchor, options)    once; returns the side used
//   anchor(panel, anchor, options)   now, and again on scroll, resize and when
//                                    the panel changes size; returns release()
//   placeAt(panel, { x, y }, options) at a point, for a context menu
//
// Options: side ("bottom" or "top", flipped when it doesn't fit and the other
// does), align ("start", "center" or "end" along the anchor, following the
// document's direction), gap (px from the anchor) and margin (px from the
// viewport's edge). The panel must be position: fixed in viewport coordinates,
// which a popover in the top layer is. It writes style.top and style.left and
// data-side and data-align, and never shows or hides anything.

const DEFAULTS = { side: "bottom", align: "center", gap: 8, margin: 8 }

export function place(panel, anchor, options = {}) {
  const { side, align, gap, margin } = { ...DEFAULTS, ...options }
  const reference = anchor.getBoundingClientRect()
  const box = panel.getBoundingClientRect()
  const width = document.documentElement.clientWidth
  const height = document.documentElement.clientHeight
  const rtl = getComputedStyle(panel).direction === "rtl"

  const above = reference.top - box.height - gap
  const below = reference.bottom + gap
  const fitsAbove = above >= margin
  const fitsBelow = below + box.height <= height - margin
  const top = side === "top" ? (fitsAbove || !fitsBelow ? above : below) : (fitsBelow || !fitsAbove ? below : above)

  const start = rtl ? reference.right - box.width : reference.left
  const end = rtl ? reference.left : reference.right - box.width
  const centred = reference.left + reference.width / 2 - box.width / 2
  const wanted = align === "start" ? start : align === "end" ? end : centred
  const left = Math.max(margin, Math.min(wanted, width - box.width - margin))

  panel.style.top = `${Math.max(margin, top)}px`
  panel.style.left = `${left}px`
  panel.dataset.side = top === above ? "top" : "bottom"
  panel.dataset.align = align
  return panel.dataset.side
}

export function placeAt(panel, point, options = {}) {
  const virtual = { getBoundingClientRect: () => ({ top: point.y, bottom: point.y, left: point.x, right: point.x, width: 0, height: 0 }) }
  return place(panel, virtual, { align: "start", gap: 2, ...options })
}

export function anchor(panel, reference, options = {}) {
  let frame = null
  const again = () => {
    if (frame) return
    frame = requestAnimationFrame(() => {
      frame = null
      place(panel, reference, options)
    })
  }

  place(panel, reference, options)
  window.addEventListener("scroll", again, { passive: true, capture: true })
  window.addEventListener("resize", again, { passive: true })
  const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(again)
  observer?.observe(panel)

  let released = false
  return () => {
    if (released) return
    released = true
    if (frame) cancelAnimationFrame(frame)
    window.removeEventListener("scroll", again, { capture: true })
    window.removeEventListener("resize", again)
    observer?.disconnect()
  }
}

// Below this width an anchored panel is better as a sheet along the bottom of
// the screen, where a thumb is. Menus and popovers ask before anchoring.
export const SHEET = "(max-width: 40rem)"

export function sheet() {
  return matchMedia(SHEET).matches
}
