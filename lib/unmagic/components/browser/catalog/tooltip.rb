# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :tooltip,
  name: "Tooltip",
  helper: "tooltip",
  import: "unmagic/components/tooltip",
  description: "A hint on hover or focus, drawn in the top layer so nothing clips it. It flips to the other " \
               "side when there isn't room, stays on screen, and closes on Escape.",
  examples: [
    { key: :term, title: "A term in a sentence",
      description: "Plain text content is styled as a term — a dashed underline — and made focusable." },
    { key: :placement, title: "Placement and edges", layout: :full,
      description: "placement: :bottom flips above when there's no room; a hint near the edge is clamped on screen." }
  ]
