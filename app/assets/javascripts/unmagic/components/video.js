// <unmagic-video id="…" provider="native|stream" src="…"> — a video the page
// drives with its own controls, rendered by `video_player`.
//
// It has no UI of its own. Buttons anywhere on the page control it with invoker
// commands, naming it with commandfor and the action with command (its argument
// in value):
//
//   <button commandfor="tour" command="--seek" value="1:12">The workshop</button>
//
//   --play --pause --toggle            --seek "72" | "1:12" (and plays)
//   --skip "10" | "-10"                --chapter "2" (index)
//   --next-chapter --previous-chapter  --mute --unmute --toggle-mute
//   --rate "1.5"                       --fullscreen
//
// Browsers without invoker commands get the same through one delegated click
// listener. What's inside:
//
//   <unmagic-video-chapter start="72" end="…" hidden>Title</unmagic-video-chapter>
//       the chapters, as data; a native <video>'s <track kind="chapters"> is
//       read when there are none, and `chapters` can be set from script
//   <unmagic-video-cover>…</unmagic-video-cover>
//       anything shown over the video until it starts, then hidden
//   <video>   for provider="native", optional: built from src when missing
//
// What it keeps true, for the page's CSS and assistive technology:
//
//   on itself         playing, started, ended, muted, current-chapter="1"
//   on its controls   aria-current="true" on the --seek/--chapter button for the
//                     chapter playing; aria-pressed on --toggle/--toggle-mute
//   <output for="tour" name="chapter|chapter-index|time|duration|remaining">
//
// Events, which bubble: unmagic-video:ready { duration }, :play { first },
// :pause, :ended, :timeupdate { currentTime }, :chapterchange { chapter,
// previous }, :error { message }. Script can call play(), pause() and
// seek(seconds), and read currentTime, duration, paused, muted, chapters and
// currentChapter.

import { PROVIDERS } from "unmagic/components/video_providers"

const SEEK_COMMANDS = ["--seek", "--chapter"]

class UnmagicVideo extends HTMLElement {
  #provider = null
  #chapters = []
  #assigned = null
  #current = -1
  #played = false
  #observer = null
  #outputs = ""

  constructor() {
    super()
    this.addEventListener("command", this.#command)
  }

  connectedCallback() {
    installCommandFallback()
    this.#observer = new MutationObserver(this.#mutated)
    this.#observer.observe(this, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: [ "start", "end" ] })
    for (const type of TURBO_EVENTS) document.addEventListener(type, this.#refresh)
    document.addEventListener("turbo:before-cache", this.#beforeCache)

    // A restored snapshot can hold the iframe a previous visit built.
    const provider = this.getAttribute("provider") === "stream" ? "stream" : "native"
    if (provider === "stream") this.querySelectorAll(":scope > iframe").forEach((iframe) => iframe.remove())

    this.#provider?.destroy()
    this.#provider = new PROVIDERS[provider](this, this.#notified)
    providers.set(this, this.#provider)
    // With nothing to cover it, a Stream player shows itself straight away.
    if (!this.querySelector(":scope > unmagic-video-cover")) this.#provider.mount()
    this.#readChapters()
    this.#reflect({ force: true })
  }

  disconnectedCallback() {
    this.#observer?.disconnect()
    for (const type of TURBO_EVENTS) document.removeEventListener(type, this.#refresh)
    document.removeEventListener("turbo:before-cache", this.#beforeCache)
    this.#provider?.destroy()
    this.#provider = null
    providers.delete(this)
  }

  get currentTime() { return this.#provider?.currentTime || 0 }
  get duration() { return this.#provider?.duration || 0 }
  get paused() { return this.#provider ? this.#provider.paused : true }
  get muted() { return !!this.#provider?.muted }
  get chapters() { return this.#chapters.map(({ start, end, title }) => ({ start, end, title })) }
  get currentChapter() { return this.#current < 0 ? null : { index: this.#current, ...this.chapters[this.#current] } }

  set chapters(chapters) {
    this.#assigned = chapters ? Array.from(chapters, (chapter) => ({ ...chapter, start: parseTime(chapter.start) })) : null
    this.#readChapters()
  }

  play() { return this.#provider?.play() }
  pause() { this.#provider?.pause() }

  seek(seconds) {
    if (!this.#provider) return
    const time = clamp(seconds, this.duration)
    this.#provider.seek(time)
    this.#markChapter(time)
    this.#provider.play()
  }

  #command = (event) => {
    const command = event.command
    if (!command?.startsWith("--")) return

    const value = event.source?.value ?? event.source?.getAttribute?.("value") ?? ""
    const action = COMMANDS[command]
    if (!action) return

    action(this, value)
    if (SEEK_COMMANDS.includes(command) || command.endsWith("-chapter")) this.#reveal()
  }

  // What the provider heard from the media.
  #notified = (type, value) => {
    switch (type) {
      case "ready":
        this.#readChapters()
        this.#emit("ready", { duration: this.duration })
        break
      case "play": {
        const first = !this.#played
        this.#played = true
        this.#emit("play", { first })
        break
      }
      case "pause":
        this.#emit("pause")
        break
      case "ended":
        this.#emit("ended")
        break
      case "time":
        this.#markChapter(value)
        this.#emit("timeupdate", { currentTime: value })
        break
      case "duration":
        this.#readChapters()
        break
      case "error":
        this.#emit("error", { message: value })
        break
    }
    this.#reflect()
  }

  #mutated = () => {
    this.#readChapters()
  }

  // The snapshot keeps the server's markup: stopped, with the cover showing.
  #beforeCache = () => {
    this.pause()
    this.querySelectorAll(":scope > unmagic-video-cover").forEach((cover) => { cover.hidden = false })
    for (const name of [ "playing", "started", "ended", "current-chapter" ]) this.removeAttribute(name)
  }

  #refresh = () => {
    this.#readChapters()
    this.#reflect({ force: true })
  }

  // The chapters, in the order they run, each ending where the next begins.
  #readChapters() {
    let chapters = this.#assigned
    if (!chapters) {
      chapters = [...this.querySelectorAll("unmagic-video-chapter")].map((element) => ({
        start: parseTime(element.getAttribute("start")),
        end: element.hasAttribute("end") ? parseTime(element.getAttribute("end")) : null,
        title: element.textContent.replace(/\s+/g, " ").trim()
      }))
    }
    if (!chapters.length) chapters = this.#trackChapters()

    chapters = chapters.filter((chapter) => Number.isFinite(chapter.start)).sort((a, b) => a.start - b.start)
    chapters.forEach((chapter, index) => {
      chapter.end ??= chapters[index + 1]?.start ?? (this.duration || null)
    })

    this.#chapters = chapters
    this.#current = -1
    this.#markChapter(this.currentTime, { silent: true })
  }

  #trackChapters() {
    const track = this.#provider?.chapterTrack()
    if (!track?.track) return []

    if (track.track.mode === "disabled") {
      track.track.mode = "hidden"
      track.addEventListener("load", () => this.#readChapters(), { once: true })
    }
    return [...(track.track.cues || [])].map((cue) => ({ start: cue.startTime, end: cue.endTime, title: cue.text }))
  }

  #markChapter(seconds, { silent = false } = {}) {
    const index = chapterAt(this.#chapters, seconds)
    if (index === this.#current) return

    const previous = this.currentChapter
    this.#current = index
    this.#reflect({ force: true })
    if (!silent) this.#emit("chapterchange", { chapter: this.currentChapter, previous })
  }

  // Attributes on the element, state on its controls, and its outputs.
  #reflect({ force = false } = {}) {
    if (!this.#provider) return
    const playing = !this.paused
    const started = this.#played || this.currentTime > 0

    this.toggleAttribute("playing", playing)
    this.toggleAttribute("started", started)
    this.toggleAttribute("ended", !playing && this.duration > 0 && this.currentTime >= this.duration - 0.25)
    this.toggleAttribute("muted", this.muted)
    if (this.#current >= 0) this.setAttribute("current-chapter", this.#current)
    else this.removeAttribute("current-chapter")

    for (const cover of this.querySelectorAll(":scope > unmagic-video-cover")) cover.hidden = started

    if (force || this.#controlsStale(playing)) this.#reflectControls(playing)
    this.#reflectOutputs()
  }

  #controlsStale(playing) {
    const key = `${playing}:${this.muted}:${this.#current}`
    if (key === this.#controlsKey) return false
    this.#controlsKey = key
    return true
  }

  #controlsKey = ""

  #reflectControls(playing) {
    if (!this.id) return

    for (const control of document.querySelectorAll(`[commandfor="${CSS.escape(this.id)}"]`)) {
      const command = control.getAttribute("command")
      if (command === "--toggle") control.setAttribute("aria-pressed", String(playing))
      else if (command === "--toggle-mute") control.setAttribute("aria-pressed", String(this.muted))
      else if (SEEK_COMMANDS.includes(command)) this.#markControl(control, command)
    }
  }

  #markControl(control, command) {
    const value = control.value ?? control.getAttribute("value")
    const index = command === "--chapter" ? Number(value) : this.#chapters.findIndex((chapter) => chapter.start === parseTime(value))
    if (index >= 0 && index === this.#current) control.setAttribute("aria-current", "true")
    else control.removeAttribute("aria-current")
  }

  #reflectOutputs() {
    if (!this.id) return
    const chapter = this.currentChapter
    const values = {
      chapter: chapter?.title ?? "",
      "chapter-index": chapter ? String(chapter.index + 1) : "",
      time: formatTime(this.currentTime),
      duration: this.duration ? formatTime(this.duration) : "",
      remaining: this.duration ? `-${formatTime(Math.max(0, this.duration - this.currentTime))}` : ""
    }
    const key = JSON.stringify(values)
    if (key === this.#outputs) return
    this.#outputs = key

    for (const output of document.querySelectorAll(`output[for~="${CSS.escape(this.id)}"]`)) {
      const value = values[output.getAttribute("name")]
      if (value !== undefined && output.textContent !== value) output.textContent = value
    }
  }

  // A chapter pressed with the player out of sight brings it back, or the click
  // looks dead.
  #reveal() {
    const motion = matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth"
    this.scrollIntoView({ behavior: motion, block: "nearest" })
  }

  #emit(name, detail = {}) {
    this.dispatchEvent(new CustomEvent(`unmagic-video:${name}`, { bubbles: true, detail }))
  }
}

const COMMANDS = {
  "--play": (player) => player.play(),
  "--pause": (player) => player.pause(),
  "--toggle": (player) => (player.paused ? player.play() : player.pause()),
  "--seek": (player, value) => player.seek(parseTime(value)),
  "--skip": (player, value) => player.seek(player.currentTime + (Number(value) || 0)),
  "--chapter": (player, value) => seekChapter(player, Number(value)),
  "--next-chapter": (player) => seekChapter(player, (player.currentChapter?.index ?? -1) + 1),
  "--previous-chapter": (player) => {
    const chapter = player.currentChapter
    // Like a CD player: back to this chapter's start, or the one before if
    // it has only just begun.
    const index = chapter && player.currentTime - chapter.start < 3 ? chapter.index - 1 : (chapter?.index ?? 0)
    seekChapter(player, Math.max(0, index))
  },
  "--mute": (player) => setMuted(player, true),
  "--unmute": (player) => setMuted(player, false),
  "--toggle-mute": (player) => setMuted(player, !player.muted),
  "--rate": (player, value) => providerOf(player)?.setRate(Number(value) || 1),
  "--fullscreen": (player) => {
    const element = providerOf(player)?.fullscreenElement || player
    if (document.fullscreenElement) document.exitFullscreen()
    else element.requestFullscreen?.()
  }
}

const providers = new WeakMap()

function providerOf(player) {
  return providers.get(player)
}

function seekChapter(player, index) {
  const chapter = player.chapters[index]
  if (chapter) player.seek(chapter.start)
}

function setMuted(player, muted) {
  providerOf(player)?.setMuted(muted)
}

// Every chapter that starts at or before seconds; the last of them.
function chapterAt(chapters, seconds) {
  let index = -1
  chapters.forEach((chapter, i) => {
    if (chapter.start <= seconds + 0.01) index = i
  })
  return index
}

// "72", "1:12" or "1:01:12" in seconds.
export function parseTime(value) {
  if (typeof value === "number") return value
  const text = String(value ?? "").trim()
  if (!text) return NaN
  return text.split(":").reduce((total, part) => total * 60 + Number(part), 0)
}

// Seconds as a player's clock: "1:12", widening to "1:01:12" past the hour.
export function formatTime(seconds) {
  const whole = Math.max(0, Math.floor(seconds || 0))
  const hours = Math.floor(whole / 3600)
  const minutes = Math.floor((whole % 3600) / 60)
  const secs = String(whole % 60).padStart(2, "0")
  return hours ? `${hours}:${String(minutes).padStart(2, "0")}:${secs}` : `${minutes}:${secs}`
}

function clamp(seconds, duration) {
  const time = Math.max(0, Number(seconds) || 0)
  return duration ? Math.min(time, duration) : time
}

const TURBO_EVENTS = ["turbo:load", "turbo:render", "turbo:frame-render", "turbo:morph"]

// Browsers without invoker commands: a click on a [commandfor] button sends the
// same command event its target would get natively.
const FALLBACK = Symbol.for("unmagic-video:command-fallback")

function installCommandFallback() {
  if (document[FALLBACK] || "commandForElement" in HTMLButtonElement.prototype) return
  document[FALLBACK] = true

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.("button[commandfor][command^='--']")
    if (!button || button.disabled) return

    const target = document.getElementById(button.getAttribute("commandfor"))
    if (!(target instanceof UnmagicVideo)) return

    const command = new Event("command", { cancelable: true })
    Object.defineProperties(command, { command: { value: button.getAttribute("command") }, source: { value: button } })
    target.dispatchEvent(command)
  })
}

customElements.get("unmagic-video") || customElements.define("unmagic-video", UnmagicVideo)

export { UnmagicVideo }
