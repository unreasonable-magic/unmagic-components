# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :scroll_area,
  name: "Scroll area",
  group: "Layout",
  new: true,
  helper: "scroll_area",
  import: nil,
  description: "A box that scrolls, with shadows where there is more to see and a thin themed scrollbar. No " \
               "script: the shadows are scroll-bound backgrounds.",
  examples: [
    { key: :list, title: "A long list, capped", layout: :full,
      description: "max_height: caps it; label: makes it a named region a keyboard can reach and scroll." },
    { key: :wide, title: "Sideways", layout: :full,
      description: "axis: :x for a board wider than its box." }
  ]
