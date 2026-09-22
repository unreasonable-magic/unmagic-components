# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :empty_state,
  name: "Empty state",
  group: "Layout",
  helper: "empty_state",
  import: nil,
  description: "The dashed blank slate a list or table shows when there is nothing in it. It renders through " \
               "the same empty_state seam as a table's, so an app that replaces one gets both.",
  examples: [
    { key: :default, title: "Default", layout: :full },
    { key: :rich, title: "With a title, an icon and a way out", layout: :full,
      description: "title: heads it, icon: is a glyph above that, and the block is the actions that fix it." }
  ]
