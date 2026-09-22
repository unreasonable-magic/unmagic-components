# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :separator,
  name: "Separator",
  group: "Layout",
  helper: "separator",
  import: nil,
  description: "A rule between two things: a plain <hr>, one with a word on it, or an upright one between items " \
               "in a row.",
  examples: [
    { key: :rules, title: "Plain, worded and upright", layout: :full }
  ]
