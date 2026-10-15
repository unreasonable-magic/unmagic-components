// <unmagic-dropzone input="#files"> — a region that takes dropped and pasted
// files, rendered by `ai_chat_dropzone`.
//
// Dragging files over it shows its overlay (data-dragging); dropping or pasting
// them attaches them. Dragging is never the only way in: the paired file input is
// the keyboard's route, and files picked through it are attached the same way.
//
//   input="#files"     the file input (required)
//   url="/uploads"     upload each file on the spot: POST, as `file`, expecting JSON
//                      back with a `value`, which is then posted with the message
//                      as a hidden field named by `field`. Without a url, the files
//                      wait on the input and go with the form.
//   field="message[attachments][]"
//   chips="#composer [data-ai-chat-chips]"   where attached files are listed
//
// Chips are cloned from the element's own <template data-dropzone-chip>, and a
// polite live region says what was attached. It fires unmagic-dropzone:attach and
// unmagic-dropzone:error, clears its chips once the form submits successfully, and
// drops the overlay before Turbo caches the page. Needs Turbo for that clearing.

class UnmagicDropzone extends HTMLElement {
  #depth = 0
  #transfer = new DataTransfer()
  #input = null

  constructor() {
    super()
    this.addEventListener("dragenter", (event) => {
      if (!hasFiles(event)) return
      this.#depth++
      this.setAttribute("data-dragging", "")
    })
    this.addEventListener("dragleave", (event) => {
      if (!hasFiles(event)) return
      this.#depth = Math.max(0, this.#depth - 1)
      if (this.#depth === 0) this.removeAttribute("data-dragging")
    })
    this.addEventListener("dragover", (event) => {
      if (!hasFiles(event)) return
      event.preventDefault()
      event.dataTransfer.dropEffect = "copy"
    })
    this.addEventListener("drop", (event) => {
      if (!hasFiles(event)) return
      event.preventDefault()
      this.#reset()
      this.attach(event.dataTransfer.files)
    })
    this.addEventListener("paste", (event) => {
      const files = event.clipboardData?.files
      if (files?.length) this.attach(files)
    })
  }

  connectedCallback() {
    this.#input = document.querySelector(this.getAttribute("input"))
    this.#input?.addEventListener("change", this.#picked)
    document.addEventListener("turbo:before-cache", this.#reset)
    document.addEventListener("turbo:submit-end", this.#submitted)
  }

  disconnectedCallback() {
    this.#input?.removeEventListener("change", this.#picked)
    this.#input = null
    document.removeEventListener("turbo:before-cache", this.#reset)
    document.removeEventListener("turbo:submit-end", this.#submitted)
  }

  attach(files) {
    for (const file of Array.from(files)) {
      if (this.hasAttribute("url")) this.#upload(file)
      else this.#hold(file)
    }
  }

  get #chips() {
    return document.querySelector(this.getAttribute("chips")) ?? this.querySelector("[data-ai-chat-chips]")
  }

  // The input's own files are replaced by the full set, so a second pick adds to
  // the first rather than replacing it.
  #picked = () => {
    const added = Array.from(this.#input.files).filter((file) => !this.#holds(file))
    if (this.hasAttribute("url")) {
      this.#input.value = ""
      for (const file of added) this.#upload(file)
    } else {
      for (const file of added) this.#hold(file)
    }
  }

  #holds(file) {
    return Array.from(this.#transfer.files).some((held) => held === file)
  }

  #hold(file) {
    if (!this.#input) return
    this.#transfer.items.add(file)
    this.#input.files = this.#transfer.files

    this.#chip(file, () => {
      const kept = new DataTransfer()
      for (const held of this.#transfer.files) if (held !== file) kept.items.add(held)
      this.#transfer = kept
      this.#input.files = kept.files
    })
    this.#attached(file)
  }

  async #upload(file) {
    const body = new FormData()
    body.append("file", file)
    const token = document.querySelector("meta[name=csrf-token]")?.content

    try {
      const response = await fetch(this.getAttribute("url"), {
        method: "POST",
        body,
        headers: { Accept: "application/json", ...(token ? { "X-CSRF-Token": token } : {}) },
        credentials: "same-origin",
      })
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`)

      const { value } = await response.json()
      const chip = this.#chip(file)
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = this.getAttribute("field")
      hidden.value = value
      chip?.append(hidden)
      this.#attached(file)
    } catch (error) {
      this.#say("failed", file)
      this.dispatchEvent(new CustomEvent("unmagic-dropzone:error", { bubbles: true, detail: { file, error } }))
    }
  }

  #chip(file, removed = () => {}) {
    const template = this.querySelector(":scope > template[data-dropzone-chip]")
    const chips = this.#chips
    if (!template || !chips) return null

    const chip = template.content.firstElementChild.cloneNode(true)
    chip.querySelector("[data-dropzone-name]").textContent = file.name
    chip.querySelector("[data-dropzone-size]").textContent = humanSize(file.size)

    const remove = chip.querySelector("[data-dropzone-remove]")
    const label = this.#words("remove", file)
    remove.setAttribute("aria-label", label)
    remove.title = label
    remove.addEventListener("click", () => {
      chip.remove()
      removed()
    })

    chips.append(chip)
    return chip
  }

  #attached(file) {
    this.#say("attached", file)
    this.dispatchEvent(new CustomEvent("unmagic-dropzone:attach", { bubbles: true, detail: { file } }))
  }

  #say(key, file) {
    const status = this.querySelector(":scope > [data-dropzone-status]")
    if (status) status.textContent = this.#words(key, file)
  }

  #words(key, file) {
    return (this.dataset[key] || "").replaceAll("{name}", file.name)
  }

  // The files went with the message: forget them.
  #submitted = (event) => {
    const form = this.#input?.form ?? this.#chips?.closest("form")
    if (event.target !== form || !event.detail?.success) return

    this.#chips?.replaceChildren()
    this.#transfer = new DataTransfer()
    if (this.#input) this.#input.value = ""
  }

  #reset = () => {
    this.#depth = 0
    this.removeAttribute("data-dragging")
  }
}

function hasFiles(event) {
  return Array.from(event.dataTransfer?.types ?? []).includes("Files")
}

function humanSize(bytes) {
  if (bytes < 1024) return `${bytes} Bytes`
  const units = ["KB", "MB", "GB"]
  let size = bytes / 1024
  let unit = 0
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024
    unit++
  }
  return `${size < 10 ? size.toFixed(1).replace(/\.0$/, "") : Math.round(size)} ${units[unit]}`
}

customElements.get("unmagic-dropzone") || customElements.define("unmagic-dropzone", UnmagicDropzone)
