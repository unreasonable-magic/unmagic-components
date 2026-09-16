# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :badge,
  name: "Badge",
  helper: "badge",
  import: nil,
  description: "A small pill of text: a status, a count, a label.",
  examples: [
    { key: :tones, title: "Tones" },
    { key: :in_context, title: "Beside the thing it describes" }
  ]
