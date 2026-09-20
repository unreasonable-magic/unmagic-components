# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :section,
  name: "Section",
  group: "Layout",
  new: true,
  helper: "section",
  import: nil,
  description: "A titled run of a page: a small heading with what qualifies it beside it, the button that acts on " \
               "the run hard right, and the run itself.",
  examples: [
    { key: :runs, title: "Two runs of a page", layout: :full,
      description: "aside is what qualifies the title; actions is the button that acts on the whole run. " \
                   "spacing: :tight closes up the first run on a page." }
  ]
