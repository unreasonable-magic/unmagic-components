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
// time-ordered ids (UUIDv7, ULID); with random ids the position is stable but arbitrary. The rule
// itself lives in placement.js, shared with <unmagic-optimistic>.
//
// A list showing newest first says so, and the comparison flips:
//
//   <turbo-stream action="upsert" target="task_rows" order="desc">
//
//   broadcast_action_to "tasks", action: :upsert, target: "task_rows",
//     attributes: { order: "desc" }, partial: "tasks/row", locals: { task: self }
import { Turbo } from "@hotwired/turbo-rails"
import { place } from "unmagic/components/placement"

Turbo.StreamActions.upsert = function () {
  const incoming = this.templateContent.firstElementChild
  if (!incoming) return

  place(incoming, this.targetElements[0], { descending: this.getAttribute("order") === "desc" })
}
