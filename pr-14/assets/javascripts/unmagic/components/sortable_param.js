// <unmagic-sortable-param name="column_id" value="3"> — one field a list posts
// with a drop into it, rendered by `sortable_list`'s params:. It shows nothing.

class UnmagicSortableParam extends HTMLElement {
  get name() {
    return this.getAttribute("name")
  }

  get value() {
    return this.getAttribute("value")
  }
}

customElements.get("unmagic-sortable-param") || customElements.define("unmagic-sortable-param", UnmagicSortableParam)
