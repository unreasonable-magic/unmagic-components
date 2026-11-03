// Places an element by its id: the reconcile-by-id contract the `upsert` stream
// action and <unmagic-optimistic> both keep, so the two can never disagree about
// where something lands.
//
// If an element with the incoming one's id is already in the document —
// server-rendered, streamed in earlier, or an optimistic placeholder the server is
// now confirming — it is replaced where it stands. Otherwise the incoming element
// is inserted into the container at the position its id sorts to, so
// out-of-order delivery still lands in id order. That ordering assumes
// time-ordered ids (UUIDv7, ULID); with random ids the position is stable but
// arbitrary. An element without an id goes last.

export function place(incoming, container, { descending = false } = {}) {
  const existing = incoming.id ? document.getElementById(incoming.id) : null
  if (existing) {
    existing.replaceWith(incoming)
    return incoming
  }

  if (!container) return null

  const successor = incoming.id
    ? Array.from(container.children).find(
        (child) => child.id && (descending ? child.id < incoming.id : child.id > incoming.id),
      )
    : null

  container.insertBefore(incoming, successor ?? null)
  return incoming
}
