// <unmagic-time> — a timestamp in the viewer's own locale and time zone, rendered
// by `local_time_tag`.
//
//   <unmagic-time datetime="2026-09-16T04:33:24Z" format="relative">
//     <time datetime="2026-09-16T04:33:24Z">about 3 hours ago</time>
//   </unmagic-time>
//
// The server's text is the fallback until this upgrades; after that the element
// writes into its <time> with Intl, so the words come from the browser's locale
// rather than from anything hand-written here.
//
// Attributes:
//   datetime  an ISO 8601 timestamp
//   format    short | medium | long | full (a date and a time), date, time, or
//             relative. Defaults to medium.
//   compact   on a relative time, "5m" rather than "5 minutes ago"
//
// A relative time keeps itself current from one shared, minute-aligned clock, and
// stops ticking once it has settled into a date (a week out).

const ABSOLUTE = {
  short: { dateStyle: "short", timeStyle: "short" },
  medium: { dateStyle: "medium", timeStyle: "short" },
  long: { dateStyle: "long", timeStyle: "short" },
  full: { dateStyle: "full", timeStyle: "long" },
  date: { dateStyle: "medium" },
  time: { timeStyle: "short" },
}

class UnmagicTime extends HTMLElement {
  static observedAttributes = ["datetime", "format", "compact"]

  #unsubscribe = null

  connectedCallback() {
    this.#render()
  }

  disconnectedCallback() {
    this.#stopTicking()
  }

  attributeChangedCallback() {
    if (this.isConnected) this.#render()
  }

  get #target() {
    return this.querySelector(":scope > time") ?? this
  }

  #render() {
    const date = new Date(this.getAttribute("datetime"))
    if (Number.isNaN(date.getTime())) return

    const format = this.getAttribute("format") || "medium"
    if (format === "relative") {
      this.#renderRelative(date)
    } else {
      this.#stopTicking()
      this.#target.textContent = formatter(ABSOLUTE[format] ?? ABSOLUTE.medium).format(date)
    }
  }

  #renderRelative(date) {
    const { text, live } = relative(date, new Date(), this.hasAttribute("compact"))
    const target = this.#target
    target.textContent = text
    target.title = formatter({ dateStyle: "long", timeStyle: "short" }).format(date)

    if (live && !this.#unsubscribe) this.#unsubscribe = subscribe(() => this.#render())
    if (!live) this.#stopTicking()
  }

  #stopTicking() {
    this.#unsubscribe?.()
    this.#unsubscribe = null
  }
}

// The ladder: under a minute, minutes, hours while it's still the same day,
// yesterday/tomorrow, days within the week, then a date that no longer changes.
// Days are calendar days in the viewer's zone, so "yesterday" turns at midnight.
//
// Units round to the nearest, not down: a time rendered two hours ahead is a few
// seconds under two hours by the time this runs, and should still say "in 2 hours".
function relative(date, now, compact) {
  const seconds = Math.round((date - now) / 1000)
  const sign = Math.sign(seconds) || -1
  const minutes = Math.round(Math.abs(seconds) / 60)
  const hours = Math.round(Math.abs(seconds) / 3600)
  const days = calendarDays(date, now)

  if (minutes === 0) return { text: phrase(0, "second", compact), live: true }
  if (minutes < 60) return { text: phrase(sign * minutes, "minute", compact), live: true }
  if (days === 0) return { text: phrase(sign * hours, "hour", compact), live: true }
  if (Math.abs(days) <= 6) return { text: phrase(days, "day", compact), live: true }

  const options = { day: "numeric", month: compact ? "short" : "long" }
  if (date.getFullYear() !== now.getFullYear()) options.year = "numeric"
  return { text: formatter(options).format(date), live: false }
}

// "now", "5 minutes ago", "yesterday", "in 3 days" — or, compact, "5m", "3h".
function phrase(value, unit, compact) {
  if (compact && value !== 0) {
    return formatter({ style: "unit", unit, unitDisplay: "narrow" }, Intl.NumberFormat).format(Math.abs(value))
  }
  return formatter({ numeric: "auto", style: compact ? "narrow" : "long" }, Intl.RelativeTimeFormat).format(value, unit)
}

function calendarDays(date, now) {
  const midnight = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate())
  return Math.round((midnight(date) - midnight(now)) / 86_400_000)
}

// Building an Intl formatter is the only real cost here, so each is made once and
// shared by every element on the page.
const formatters = new Map()
function formatter(options, Formatter = Intl.DateTimeFormat) {
  const key = `${Formatter.name}:${JSON.stringify(options)}`
  if (!formatters.has(key)) formatters.set(key, new Formatter(undefined, options))
  return formatters.get(key)
}

// One timer for every live element, aligned to the wall-clock minute, so a page of
// relative times rolls over together. It pauses while the tab is hidden and
// catches up the moment it's seen again.
const subscribers = new Set()
let timer = null
let watchingVisibility = false

function subscribe(callback) {
  if (!watchingVisibility) {
    watchingVisibility = true
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) return stop()
      notify()
      schedule()
    })
  }

  subscribers.add(callback)
  schedule()

  return () => {
    subscribers.delete(callback)
    if (subscribers.size === 0) stop()
  }
}

function schedule() {
  if (timer || subscribers.size === 0 || document.hidden) return
  timer = setTimeout(() => {
    timer = null
    notify()
    schedule()
  }, 60_000 - (Date.now() % 60_000))
}

function stop() {
  clearTimeout(timer)
  timer = null
}

function notify() {
  for (const callback of [...subscribers]) callback()
}

customElements.get("unmagic-time") || customElements.define("unmagic-time", UnmagicTime)
