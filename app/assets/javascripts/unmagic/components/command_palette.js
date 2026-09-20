// <unmagic-command-palette hotkey="mod+k"> — a dialog with a search box over
// every command in the app, rendered by `command_palette`. The combobox inside
// does the filtering and choosing (mode="activate" clicks the command's own link
// or form); this opens the dialog on the shortcut or the trigger button, clears
// the search each time, and closes once a command has been activated.

import "unmagic/components/dialog"
import "unmagic/components/combobox"

class UnmagicCommandPalette extends HTMLElement {
  connectedCallback() {
    document.addEventListener("keydown", this.#shortcut)
    this.addEventListener("unmagic-combobox:activate", this.#activated)
    this.addEventListener("close", this.#closed, true)
  }

  disconnectedCallback() {
    document.removeEventListener("keydown", this.#shortcut)
    this.removeEventListener("unmagic-combobox:activate", this.#activated)
    this.removeEventListener("close", this.#closed, true)
  }

  get dialog() {
    return this.querySelector(":scope > dialog")
  }

  get input() {
    return this.querySelector("input[role=combobox]")
  }

  open() {
    const dialog = this.dialog
    if (!dialog || dialog.open) return
    dialog.showModal()
    const input = this.input
    if (input) {
      input.value = ""
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.focus()
    }
  }

  close() {
    this.dialog?.close()
  }

  toggle() {
    this.dialog?.open ? this.close() : this.open()
  }

  #shortcut = (event) => {
    const hotkey = this.getAttribute("hotkey")
    if (!hotkey) return

    const keys = hotkey.toLowerCase().split("+")
    const key = keys.at(-1)
    const mod = keys.includes("mod") ? (navigator.platform.includes("Mac") || /iPhone|iPad/.test(navigator.userAgent) ? event.metaKey : event.ctrlKey) : true
    const shift = keys.includes("shift") === event.shiftKey
    const alt = keys.includes("alt") === event.altKey
    if (!mod || !shift || !alt || event.key.toLowerCase() !== key) return

    const editing = event.target instanceof HTMLElement && (event.target.isContentEditable || /^(input|textarea|select)$/i.test(event.target.tagName))
    if (editing && !keys.includes("mod")) return

    event.preventDefault()
    this.toggle()
  }

  #activated = () => setTimeout(() => this.close())

  #closed = () => {
    const input = this.input
    if (input) input.value = ""
  }
}

customElements.get("unmagic-command-palette") || customElements.define("unmagic-command-palette", UnmagicCommandPalette)
