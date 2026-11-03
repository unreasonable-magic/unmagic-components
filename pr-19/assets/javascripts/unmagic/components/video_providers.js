// The players behind <unmagic-video>. Each wraps one kind of media in the same
// small interface, and reports what the media does through `notify(type, value)`:
//
//   ready (duration) · play · pause · ended · time (seconds) · duration (seconds)
//   · muted (boolean) · error (message)
//
//   mount({ autoplay, start })   put the media in place (a no-op once mounted)
//   play() pause() seek(seconds) setMuted(boolean) setRate(number)
//   currentTime duration paused muted   the last values the media reported
//   fullscreenElement                   what to send fullscreen
//   chapterTrack()                      a <track kind="chapters"> to read, if any
//   destroy()                           drop listeners; leave the markup

// A <video> already inside the element, or one built from src.
export class NativeProvider {
  #host
  #notify
  #video = null

  constructor(host, notify) {
    this.#host = host
    this.#notify = notify
    this.#attach(host.querySelector("video") || this.#build())
  }

  get mounted() { return true }
  get currentTime() { return this.#video.currentTime || 0 }
  get duration() { return finite(this.#video.duration) }
  get paused() { return this.#video.paused }
  get muted() { return this.#video.muted }
  get fullscreenElement() { return this.#video }

  mount() {}

  play() {
    return this.#video.play().catch((error) => this.#notify("error", error.message))
  }

  pause() { this.#video.pause() }
  seek(seconds) { this.#video.currentTime = seconds }
  setMuted(muted) { this.#video.muted = muted }
  setRate(rate) { this.#video.playbackRate = rate }

  chapterTrack() {
    return this.#video.querySelector("track[kind=chapters]")
  }

  destroy() {
    for (const [type, handler] of this.#handlers) this.#video.removeEventListener(type, handler)
  }

  #build() {
    const video = document.createElement("video")
    video.src = this.#host.getAttribute("src") || ""
    video.preload = "metadata"
    video.playsInline = true
    video.controls = this.#host.hasAttribute("controls")
    if (this.#host.hasAttribute("poster")) video.poster = this.#host.getAttribute("poster")
    this.#host.prepend(video)
    return video
  }

  #attach(video) {
    this.#video = video
    this.#handlers = [
      ["loadedmetadata", () => this.#notify("ready", this.duration)],
      ["durationchange", () => this.#notify("duration", this.duration)],
      ["play", () => this.#notify("play")],
      ["pause", () => this.#notify("pause")],
      ["ended", () => this.#notify("ended")],
      ["timeupdate", () => this.#notify("time", this.currentTime)],
      ["seeked", () => this.#notify("time", this.currentTime)],
      ["volumechange", () => this.#notify("muted", video.muted)],
      ["error", () => this.#notify("error", video.error?.message || "The video could not be played")]
    ]
    for (const [type, handler] of this.#handlers) video.addEventListener(type, handler)
    if (video.readyState >= HTMLMediaElement.HAVE_METADATA) queueMicrotask(() => this.#notify("ready", this.duration))
  }

  #handlers = []
}

// A Cloudflare Stream player in an iframe, built on first play so a page of
// videos costs nothing until one is wanted. It speaks the iframe's postMessage
// protocol: the same messages Cloudflare's own SDK sends (there's no published
// one), queued until the iframe says it's ready. A seek the iframe never
// answers rebuilds it cued at that time: slower, never stuck.
export class StreamProvider {
  static SEEK_TIMEOUT = 1500

  #host
  #notify
  #iframe = null
  #ready = false
  #queue = []
  #state = { currentTime: 0, duration: 0, paused: true, muted: false }
  #seekTimer = null

  constructor(host, notify) {
    this.#host = host
    this.#notify = notify
    window.addEventListener("message", this.#message)
  }

  get mounted() { return !!this.#iframe }
  get currentTime() { return this.#state.currentTime }
  get duration() { return this.#state.duration }
  get paused() { return this.#state.paused }
  get muted() { return this.#state.muted }
  get fullscreenElement() { return this.#iframe }

  mount({ autoplay = false, start = 0 } = {}) {
    if (this.#iframe) return

    const iframe = document.createElement("iframe")
    iframe.src = this.#url({ autoplay, start })
    iframe.title = this.#host.getAttribute("title") || this.#host.getAttribute("aria-label") || ""
    iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen"
    iframe.allowFullscreen = true
    iframe.referrerPolicy = "strict-origin-when-cross-origin"
    this.#ready = false
    this.#queue = []
    this.#state.currentTime = start
    this.#iframe = iframe
    this.#host.prepend(iframe)
  }

  play() {
    if (!this.#iframe) return this.mount({ autoplay: true, start: this.#state.currentTime })
    this.#send({ __privateUnstableMessageType: "playCommand", promiseId: Date.now() })
  }

  pause() {
    if (this.#iframe) this.#send({ __privateUnstableMessageType: "pauseCommand" })
  }

  seek(seconds) {
    if (!this.#iframe) {
      this.#state.currentTime = seconds
      return this.mount({ autoplay: true, start: seconds })
    }

    clearTimeout(this.#seekTimer)
    this.#seekTimer = setTimeout(() => this.#rebuild(seconds), StreamProvider.SEEK_TIMEOUT)
    this.#setProperty("currentTime", seconds)
    this.#state.currentTime = seconds
    this.#notify("time", seconds)
  }

  setMuted(muted) { this.#setProperty("muted", muted) }
  setRate(rate) { this.#setProperty("playbackRate", rate) }
  chapterTrack() { return null }

  destroy() {
    window.removeEventListener("message", this.#message)
    clearTimeout(this.#seekTimer)
  }

  #url({ autoplay, start }) {
    const url = new URL(this.#host.getAttribute("src"), location.href)
    if (autoplay) url.searchParams.set("autoplay", "true")
    if (start > 0) url.searchParams.set("startTime", `${Math.floor(start)}s`)
    if (!this.#host.hasAttribute("controls")) url.searchParams.set("controls", "false")
    if (this.#host.hasAttribute("poster")) url.searchParams.set("poster", this.#host.getAttribute("poster"))
    return url.toString()
  }

  #rebuild(seconds) {
    this.#iframe?.remove()
    this.#iframe = null
    this.mount({ autoplay: true, start: seconds })
  }

  #setProperty(property, value) {
    this.#send({ __privateUnstableMessageType: "setProperty", property, value })
  }

  #send(message) {
    if (this.#ready) this.#iframe.contentWindow?.postMessage(message, this.#iframe.src)
    else this.#queue.push(message)
  }

  #message = (event) => {
    if (!this.#iframe || event.source !== this.#iframe.contentWindow) return
    const data = event.data
    if (!data || !data.__privateUnstableMessageType) return

    switch (data.__privateUnstableMessageType) {
      case "iframeReady":
        this.#ready = true
        this.#queue.splice(0).forEach((message) => this.#send(message))
        break
      case "event":
        this.#event(data.eventName)
        break
      case "propertyChange":
        this.#property(data.property, data.value)
        break
    }
  }

  #event(name) {
    if (name === "play" || name === "playing") {
      this.#state.paused = false
      this.#notify("play")
    } else if (name === "pause") {
      this.#state.paused = true
      this.#notify("pause")
    } else if (name === "ended") {
      this.#state.paused = true
      this.#notify("ended")
    } else if (name === "loadedmetadata") {
      this.#notify("ready", this.#state.duration)
    } else if (name === "seeked") {
      clearTimeout(this.#seekTimer)
    }
  }

  #property(property, value) {
    if (property === "currentTime") {
      clearTimeout(this.#seekTimer)
      this.#state.currentTime = Number(value) || 0
      this.#notify("time", this.#state.currentTime)
    } else if (property === "duration") {
      this.#state.duration = finite(Number(value))
      this.#notify("duration", this.#state.duration)
    } else if (property === "muted") {
      this.#state.muted = !!value
      this.#notify("muted", this.#state.muted)
    } else if (property === "paused") {
      this.#state.paused = !!value
    }
  }
}

export const PROVIDERS = { native: NativeProvider, stream: StreamProvider }

function finite(number) {
  return Number.isFinite(number) ? number : 0
}
