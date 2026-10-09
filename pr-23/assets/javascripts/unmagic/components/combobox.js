// <unmagic-combobox> — a text input that filters a list of options, rendered by
// `combobox` (and, inline with mode="activate", by `command_palette`).
//
//   multiple           several choices, as chips with hidden inputs
//   src="/search"      fetch options as you type into the results frame
//   min-length, debounce
//   create="name[]"    submit a typed text that matches nothing
//   mode="activate"    options are commands: choosing one clicks what's inside
//
// The server renders the whole ARIA pattern. This keeps aria-expanded,
// aria-activedescendant and aria-selected true, filters options by label and
// keywords, places the popup with unmagic/components/position, and reads the
// result count to a status region. DOM focus never leaves the input.

import { anchor } from "unmagic/components/position"

const OPTIONS = "[role=option]"

class UnmagicCombobox extends HTMLElement {
  #release = null
  #timer = null
  #query = ""

  constructor() {
    super()
    this.addEventListener("input", this.#typed)
    this.addEventListener("keydown", this.#keydown)
    this.addEventListener("pointerdown", this.#pressed)
    this.addEventListener("click", this.#clicked)
    this.addEventListener("focusout", this.#left)
    this.addEventListener("turbo:frame-load", this.#loaded)
  }

  connectedCallback() {
    if (this.inline) this.#filter()
  }

  disconnectedCallback() {
    this.#release?.()
  }

  get input() {
    return this.querySelector("input[role=combobox]")
  }

  get popup() {
    return this.querySelector(":scope > .UnmagicCombobox__popup")
  }

  get listbox() {
    return this.querySelector("[role=listbox]")
  }

  get status() {
    return this.querySelector(".UnmagicCombobox__status")
  }

  get inline() {
    return this.classList.contains("UnmagicCombobox--inline")
  }

  get multiple() {
    return this.hasAttribute("multiple")
  }

  get activate() {
    return this.getAttribute("mode") === "activate"
  }

  get options() {
    return [...this.listbox.querySelectorAll(OPTIONS)]
  }

  get visible() {
    return this.options.filter((option) => !option.hidden && option.getAttribute("aria-disabled") !== "true")
  }

  get active() {
    return this.listbox.querySelector("[data-active]")
  }

  get isOpen() {
    return this.inline || (this.popup?.matches(":popover-open") ?? false)
  }

  open() {
    if (this.isOpen || !this.popup) return
    this.popup.showPopover()
    this.#release = anchor(this.popup, this.querySelector(".UnmagicCombobox__control") ?? this.input, { side: "bottom", align: "start", gap: 4 })
    this.popup.style.minWidth = `${this.getBoundingClientRect().width}px`
    this.input.setAttribute("aria-expanded", "true")
    this.#filter()
  }

  close() {
    if (this.inline || !this.isOpen) return
    this.popup.hidePopover()
    this.#release?.()
    this.#release = null
    this.input.setAttribute("aria-expanded", "false")
    this.#activate(null)
  }

  // ------------------------------------------------------------- filtering

  #typed = () => {
    this.#query = this.input.value
    if (!this.isOpen) this.open()
    this.#filter()

    const src = this.getAttribute("src")
    if (src) {
      clearTimeout(this.#timer)
      this.#timer = setTimeout(() => this.#search(src), Number(this.getAttribute("debounce")) || 200)
    }
  }

  #filter() {
    const query = (this.multiple || this.activate || this.input.value !== this.#selectedLabel() ? this.input.value : "").trim().toLowerCase()
    let shown = 0

    for (const option of this.options) {
      const text = `${option.dataset.label ?? option.textContent} ${option.dataset.keywords ?? ""}`.toLowerCase()
      const match = !query || text.includes(query)
      option.hidden = !match
      if (match) shown++
    }

    for (const group of this.listbox.querySelectorAll("[role=group]")) {
      group.hidden = !group.querySelector(`${OPTIONS}:not([hidden])`)
    }

    const empty = this.querySelector("[data-unmagic-combobox-empty]")
    if (empty) empty.hidden = shown > 0 || this.#searching
    this.#announce(shown)

    const first = this.visible[0]
    if (!this.active || this.active.hidden) this.#activate(this.activate || query ? first : null)
  }

  #searching = false

  async #search(src) {
    const frame = this.querySelector(":scope turbo-frame")
    const query = this.input.value.trim()
    if (!frame || query.length < (Number(this.getAttribute("min-length")) || 1)) return

    this.#searching = true
    this.listbox.setAttribute("aria-busy", "true")
    const searching = this.querySelector("[data-unmagic-combobox-searching]")
    if (searching) searching.hidden = false
    this.#status(searching?.textContent ?? "Searching…")

    const url = new URL(src, location.href)
    url.searchParams.set("q", query)
    frame.src = url.toString()
  }

  #loaded = (event) => {
    if (!(event.target instanceof Element) || !this.contains(event.target)) return
    this.#searching = false
    this.listbox.removeAttribute("aria-busy")
    const searching = this.querySelector("[data-unmagic-combobox-searching]")
    if (searching) searching.hidden = true
    this.#markSelected()
    this.#filter()
  }

  // Options that arrive from a search keep saying what's chosen.
  #markSelected() {
    const chosen = new Set([...this.querySelectorAll(".UnmagicCombobox__chip")].map((chip) => chip.dataset.value))
    const single = this.querySelector("[data-unmagic-combobox-value]")?.value
    for (const option of this.options) {
      option.setAttribute("aria-selected", String(this.multiple ? chosen.has(option.dataset.value) : option.dataset.value === single))
    }
  }

  // -------------------------------------------------------------- choosing

  #keydown = (event) => {
    if (event.target !== this.input) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (!this.isOpen) this.open()
        if (!event.altKey) this.#move(1)
        break
      case "ArrowUp":
        event.preventDefault()
        if (!this.isOpen) this.open()
        this.#move(-1)
        break
      case "Enter":
        if (this.active) {
          event.preventDefault()
          this.#choose(this.active, event)
        }
        break
      case "Escape":
        if (this.isOpen && !this.inline) {
          event.preventDefault()
          this.close()
        } else if (this.input.value) {
          event.preventDefault()
          this.input.value = this.multiple || this.activate ? "" : this.#selectedLabel()
          this.#filter()
        }
        break
      case "Tab":
        this.close()
        break
      case "Backspace":
        if (this.multiple && !this.input.value) {
          const last = this.querySelector(".UnmagicCombobox__chip:last-of-type")
          if (last) this.#remove(last)
        }
        break
    }
  }

  #move(step) {
    const visible = this.visible
    if (visible.length === 0) return
    const index = visible.indexOf(this.active)
    const next = index === -1 ? (step > 0 ? 0 : visible.length - 1) : (index + step + visible.length) % visible.length
    this.#activate(visible[next])
  }

  #activate(option) {
    for (const each of this.options) each.toggleAttribute("data-active", each === option)
    if (option) {
      this.input.setAttribute("aria-activedescendant", option.id)
      option.scrollIntoView({ block: "nearest" })
    } else {
      this.input.removeAttribute("aria-activedescendant")
    }
  }

  // A press on an option must not take focus from the input.
  #pressed = (event) => {
    if (event.target instanceof Element && event.target.closest(OPTIONS)) event.preventDefault()
  }

  #clicked = (event) => {
    const target = event.target
    if (!(target instanceof Element)) return

    const remove = target.closest(".UnmagicCombobox__remove")
    if (remove) {
      this.#remove(remove.closest(".UnmagicCombobox__chip"))
      return
    }

    const option = target.closest(OPTIONS)
    if (option && this.contains(option)) {
      if (this.activate && target.closest(".UnmagicCommandPalette__target")) return
      this.#choose(option, event)
    } else if (target === this.input || target.closest(".UnmagicCombobox__control")) {
      this.input.focus()
      if (!this.isOpen) this.open()
    }
  }

  #choose(option, event) {
    if (option.getAttribute("aria-disabled") === "true") return

    if (this.activate) {
      const target = option.querySelector(".UnmagicCommandPalette__target")
      this.dispatchEvent(new CustomEvent("unmagic-combobox:activate", { bubbles: true, detail: { option } }))
      if (target instanceof HTMLAnchorElement && (event.metaKey || event.ctrlKey)) window.open(target.href, "_blank")
      else target?.click()
      return
    }

    const value = option.dataset.value
    const label = option.dataset.label ?? option.textContent.trim()

    if (this.multiple) {
      const chip = this.querySelector(`.UnmagicCombobox__chip[data-value="${CSS.escape(value)}"]`)
      if (chip) this.#remove(chip)
      else this.#add(value, label)
      this.input.value = ""
      this.#filter()
    } else {
      const hidden = this.querySelector("[data-unmagic-combobox-value]")
      if (hidden) hidden.value = value
      this.input.value = label
      for (const each of this.options) each.setAttribute("aria-selected", String(each === option))
      this.close()
    }
    this.dispatchEvent(new CustomEvent("unmagic-combobox:change", { bubbles: true, detail: { value, label } }))
  }

  #add(value, label) {
    const chips = this.querySelector(".UnmagicCombobox__chips")
    const name = this.querySelector("[data-unmagic-combobox-blank]")?.name
    const template = this.querySelector(".UnmagicCombobox__chip")
    const chip = document.createElement("li")
    chip.className = "UnmagicCombobox__chip"
    chip.dataset.value = value
    chip.innerHTML = template?.innerHTML ?? `<span class="UnmagicCombobox__chip-label"></span><button type="button" class="UnmagicCombobox__remove" aria-label="Remove">×</button><input type="hidden">`
    chip.querySelector(".UnmagicCombobox__chip-label").textContent = label
    chip.querySelector(".UnmagicCombobox__remove").setAttribute("aria-label", `Remove ${label}`)
    const input = chip.querySelector("input[type=hidden]")
    input.name = name ?? input.name
    input.value = value
    chips?.append(chip)
    this.listbox.querySelector(`${OPTIONS}[data-value="${CSS.escape(value)}"]`)?.setAttribute("aria-selected", "true")
  }

  #remove(chip) {
    const value = chip.dataset.value
    chip.remove()
    this.listbox.querySelector(`${OPTIONS}[data-value="${CSS.escape(value)}"]`)?.setAttribute("aria-selected", "false")
    this.input.focus()
    this.dispatchEvent(new CustomEvent("unmagic-combobox:change", { bubbles: true, detail: { value, removed: true } }))
  }

  #left = (event) => {
    const next = event.relatedTarget
    if (next instanceof Node && this.contains(next)) return
    if (!this.multiple && !this.activate && this.input.value !== this.#selectedLabel()) this.input.value = this.#selectedLabel()
    this.close()
  }

  #selectedLabel() {
    const value = this.querySelector("[data-unmagic-combobox-value]")?.value
    if (!value) return ""
    return this.listbox.querySelector(`${OPTIONS}[data-value="${CSS.escape(value)}"]`)?.dataset.label ?? ""
  }

  #announce(count) {
    const empty = this.querySelector("[data-unmagic-combobox-empty]")
    this.#status(count === 0 ? (empty?.textContent ?? "No matches") : `${count} ${count === 1 ? "result" : "results"}`)
  }

  #status(text) {
    const status = this.status
    if (status) status.textContent = text
  }
}

customElements.get("unmagic-combobox") || customElements.define("unmagic-combobox", UnmagicCombobox)
