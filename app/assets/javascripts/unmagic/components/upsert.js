// A Turbo Stream action that merges `append` and `replace`:
//
//   <turbo-stream action="upsert" target="CONTAINER_ID">
//     <template><tr id="ELEMENT_ID">…</tr></template>
//   </turbo-stream>
//
// The template holds one element with a stable id. If an element with that id is already in the
// document — server-rendered on page load, streamed in earlier, or an optimistic placeholder the
// server is now confirming — it is replaced in place, so a record that is both on the page and
// broadcast never duplicates. Otherwise it is inserted into the target container at the position
// its id sorts to, so out-of-order delivery still lands in id order. That ordering assumes
// time-ordered ids (UUIDv7, ULID); with random ids the position is stable but arbitrary.
//
// A list showing newest first says so, and the comparison flips:
//
//   <turbo-stream action="upsert" target="task_rows" order="desc">
//
//   broadcast_action_to "tasks", action: :upsert, target: "task_rows",
//     attributes: { order: "desc" }, partial: "tasks/row", locals: { task: self }
import { Turbo } from "@hotwired/turbo-rails"

Turbo.StreamActions.upsert = function () {
  const incoming = this.templateContent.firstElementChild
  if (!incoming) return

  const existing = incoming.id ? document.getElementById(incoming.id) : null
  if (existing) {
    existing.replaceWith(incoming)
    return
  }

  const container = this.targetElements[0]
  if (!container) return

  const descending = this.getAttribute("order") === "desc"

  // Without an id there is nothing to sort on, so it goes last.
  const successor = incoming.id
    ? Array.from(container.children).find(
        (child) => child.id && (descending ? child.id < incoming.id : child.id > incoming.id),
      )
    : null

  container.insertBefore(incoming, successor ?? null)
}
