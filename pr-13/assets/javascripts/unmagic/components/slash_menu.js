// <unmagic-slash-menu trigger="/"> — commands offered on a slash in a text field,
// rendered by `ai_chat_slash_menu`.
//
// Type the trigger where a word starts and the menu opens on every command; keep
// typing to narrow it by prefix. Up and Down move (wrapping), Home and End jump,
// Enter or Tab takes the selected one, Escape closes and leaves the text. While
// it's open those keys are the menu's alone, so Enter can't send a half-typed
// message out from under it. Picking writes "/name " where the token was.
//
// The server renders every item, so what can be offered is only ever what exists.
// Focus stays in the field throughout: it is the WAI-ARIA combobox pattern, with
// aria-expanded and aria-activedescendant kept true on the field.
//
//   for="message_content"   the field's id; otherwise the composer's field, or the
//                           first textarea in the enclosing form
//   trigger="/"             the character that opens it
//   insert="%{trigger}%{name} "   what a pick writes
//
// Items are its [role=option] elements, named by data-name. It fires
// unmagic-slash-menu:pick with the name, and closes before Turbo caches the page.

class UnmagicSlashMenu extends HTMLElement {
  #field = null

  constructor() {
    super()
    // mousedown fires before the field blurs, so the cursor is still where the
    // name has to go.
    this.addEventListener("mousedown", (event) => {
      const option = event.target instanceof Element && event.target.closest("[role=option]")
      if (!option) return
      event.preventDefault()
      this.#write(option.dataset.name)
    })
  }

  connectedCallback() {
    this.#field = this.#resolveField()
    const field = this.#field
    if (field) {
      field.setAttribute("role", "combobox")
      field.setAttribute("aria-autocomplete", "list")
      field.setAttribute("aria-expanded", "false")
      if (this.#listbox) field.setAttribute("aria-controls", this.#listbox.id)
      field.addEventListener("input", this.#search)
      field.addEventListener("keydown", this.#navigate)
      field.addEventListener("blur", this.close)
    }
    document.addEventListener("turbo:before-cache", this.close)
    this.close()
  }

  disconnectedCallback() {
    const field = this.#field
    field?.removeEventListener("input", this.#search)
    field?.removeEventListener("keydown", this.#navigate)
    field?.removeEventListener("blur", this.close)
    document.removeEventListener("turbo:before-cache", this.close)
    this.#field = null
  }

  get open() {
    return !this.hidden
  }

  close = () => {
    this.hidden = true
    this.#field?.setAttribute("aria-expanded", "false")
    this.#field?.removeAttribute("aria-activedescendant")
  }

  get #listbox() {
    return this.querySelector("[role=listbox]")
  }

  get #options() {
    return Array.from(this.querySelectorAll("[role=option]"))
  }

  get #offered() {
    return this.#options.filter((option) => !option.hidden)
  }

  get #selected() {
    const offered = this.#offered
    return offered.find((option) => option.getAttribute("aria-selected") === "true") ?? offered[0]
  }

  #resolveField() {
    const id = this.getAttribute("for")
    if (id) return document.getElementById(id)

    const scope = this.closest(".UnmagicAIChatComposer") ?? this.closest("form")
    return scope?.querySelector("[data-ai-chat-composer-field]") ?? scope?.querySelector("textarea")
  }

  // A trigger starting a word, and what has been typed since, anchored to the
  // cursor: a slash in a path written further back isn't a command.
  #token() {
    const field = this.#field
    const trigger = escape(this.getAttribute("trigger") || "/")
    return field.value.slice(0, field.selectionStart).match(new RegExp(`(?:^|\\s)${trigger}([\\w-]*)$`))
  }

  #search = () => {
    const token = this.#token()
    if (!token) return this.close()

    const typed = token[1].toLowerCase()
    for (const option of this.#options) option.hidden = !option.dataset.name.toLowerCase().startsWith(typed)

    const offered = this.#offered
    if (offered.length === 0) return this.close()

    this.hidden = false
    this.#field.setAttribute("aria-expanded", "true")
    this.#select(offered[0])
  }

  #navigate = (event) => {
    if (!this.open || event.isComposing) return

    const offered = this.#offered
    const index = offered.indexOf(this.#selected)

    switch (event.key) {
      case "ArrowDown":
        this.#select(offered[(index + 1) % offered.length])
        break
      case "ArrowUp":
        this.#select(offered[(index - 1 + offered.length) % offered.length])
        break
      case "Home":
        this.#select(offered[0])
        break
      case "End":
        this.#select(offered[offered.length - 1])
        break
      case "Enter":
      case "Tab":
        if (event.shiftKey && event.key === "Enter") return
        this.#write(this.#selected?.dataset.name)
        break
      case "Escape":
        this.close()
        break
      default:
        return
    }

    event.preventDefault()
    event.stopImmediatePropagation()
  }

  #select(option) {
    for (const other of this.#options) other.setAttribute("aria-selected", other === option ? "true" : "false")
    if (!option) return
    this.#field.setAttribute("aria-activedescendant", option.id)
    option.scrollIntoView({ block: "nearest" })
  }

  #write(name) {
    const token = name && this.#token()
    if (!token) return this.close()

    const field = this.#field
    const trigger = this.getAttribute("trigger") || "/"
    const template = this.getAttribute("insert") || "%{trigger}%{name} "
    const written = template.replaceAll("%{trigger}", trigger).replaceAll("%{name}", name)
    const cursor = field.selectionStart
    const start = cursor - token[1].length - trigger.length

    field.value = field.value.slice(0, start) + written + field.value.slice(cursor)
    field.selectionStart = field.selectionEnd = start + written.length
    this.close()
    field.focus()
    field.dispatchEvent(new Event("input", { bubbles: true }))
    this.dispatchEvent(new CustomEvent("unmagic-slash-menu:pick", { bubbles: true, detail: { name } }))
  }
}

function escape(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

customElements.get("unmagic-slash-menu") || customElements.define("unmagic-slash-menu", UnmagicSlashMenu)
