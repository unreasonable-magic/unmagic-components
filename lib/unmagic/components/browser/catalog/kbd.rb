# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :kbd,
  name: "Kbd",
  group: "Data display",
  new: true,
  helper: "kbd",
  import: nil,
  description: "A key or a combination of keys drawn as key caps, with the glyphs a screen reader can't say " \
               "carrying their spoken names. :mod is ⌘ here and Ctrl there.",
  examples: [
    { key: :keys, title: "Keys, combinations and sequences",
      description: "Named keys draw glyphs; strings render as given. hotkey: takes the mod+k syntax, and " \
                   "sequence: true is keys pressed one after another." }
  ]
