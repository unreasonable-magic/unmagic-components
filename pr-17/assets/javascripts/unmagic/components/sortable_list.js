// <unmagic-sortable-list namespace="…" url="…"> — a list whose items can be
// dragged into a new place, rendered by `sortable_list` and `board`.
//
//   namespace     lists sharing one exchange items; a list without one takes only
//                 its own
//   url           where a drop is posted (PATCH); none, and the drop only fires the
//                 event below
//   orientation   vertical (default), horizontal or grid: which arrow keys move an
//                 item along the list
//   label         what the list is called in announcements
//   data-sortable-instructions, -picked, -moved, -dropped, -cancelled
//                 the words announced, with {item}, {list}, {position}, {count}
//
// A drop into this list fires unmagic-sortable:move on the item, cancelable, with
// { key, original, prev, next, params }. Unless it's cancelled the list posts:
//
//   moved      the item's key
//   original   the rank it had when it was picked up, so the server can refuse a
//              move made against a stale order
//   prev       the rank of the item now before it (blank at the start)
//   next       the rank of the item now after it (blank at the end)
//   <name>     one field per <unmagic-sortable-param> in this list: the column a
//              card was dropped into
//
// With Turbo the post goes as a Turbo form submission, so a refresh or stream in
// the response reconciles the page. unmagic-sortable's endpoint does exactly this.

let counter = 0

class UnmagicSortableList extends HTMLElement {
  #instructions = null

  get namespace() {
    return this.getAttribute("namespace") || ""
  }

  get orientation() {
    return this.getAttribute("orientation") || "vertical"
  }

  get label() {
    return this.getAttribute("label") || ""
  }

  // Whether an item that came from `origin` may be dropped here.
  accepts(origin) {
    return origin === this || (this.namespace !== "" && this.namespace === origin?.namespace)
  }

  // This list's own items, in order, leaving out those of any list inside it.
  items() {
    return [...this.querySelectorAll("unmagic-sortable-item")].filter((item) => item.list === this)
  }

  itemsExcept(item) {
    return this.items().filter((other) => other !== item)
  }

  // The first child that stays at the end whatever is dropped (an "add" tile).
  tail() {
    return [...this.children].find((child) => child.hasAttribute("data-sortable-tail")) ?? null
  }

  // A hidden element holding the keyboard instructions, which every item's
  // keyboard stop is described by. Made on demand, since a morph can remove it.
  get instructionsId() {
    if (!this.#instructions?.isConnected) {
      this.#instructions = document.createElement("span")
      this.#instructions.id = `unmagic-sortable-instructions-${++counter}`
      this.#instructions.hidden = true
      this.#instructions.textContent = this.dataset.sortableInstructions || ""
      this.append(this.#instructions)
    }
    return this.#instructions.id
  }

  submit(item) {
    const items = this.items()
    const index = items.indexOf(item)
    const params = this.#params()
    const detail = {
      key: item.key,
      original: item.rank ?? "",
      prev: items[index - 1]?.rank ?? "",
      next: items[index + 1]?.rank ?? "",
      params: Object.fromEntries(params.map((param) => [param.name, param.value])),
    }

    const proceed = item.dispatchEvent(new CustomEvent("unmagic-sortable:move", { bubbles: true, cancelable: true, detail }))
    const url = this.getAttribute("url")
    if (!proceed || !url) return

    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.hidden = true
    const token = document.querySelector("meta[name=csrf-token]")?.content
    const tokenName = document.querySelector("meta[name=csrf-param]")?.content || "authenticity_token"

    field(form, "_method", "patch")
    if (token) field(form, tokenName, token)
    field(form, "moved", detail.key)
    field(form, "original", detail.original)
    field(form, "prev", detail.prev)
    field(form, "next", detail.next)
    for (const param of params) field(form, param.name, param.value)

    document.body.append(form)
    form.requestSubmit()
    form.remove()
  }

  // This list's own params: not an inner list's, and not inside one of this list's
  // items. A board's card list sits inside its column's item, so an item around
  // the list itself doesn't count.
  #params() {
    return [...this.querySelectorAll("unmagic-sortable-param")].filter((param) => {
      if (param.closest("unmagic-sortable-list") !== this) return false
      const item = param.closest("unmagic-sortable-item")
      return !item || !this.contains(item)
    })
  }
}

function field(form, name, value) {
  const input = document.createElement("input")
  input.type = "hidden"
  input.name = name
  input.value = value ?? ""
  form.append(input)
}

customElements.get("unmagic-sortable-list") || customElements.define("unmagic-sortable-list", UnmagicSortableList)

export { UnmagicSortableList }
