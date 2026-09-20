# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :item,
  name: "Item",
  group: "Layout",
  new: true,
  helper: "item",
  import: nil,
  description: "A row about one thing, wherever a list shows it: its picture on the left, its name over a line " \
               "about it, flags beside the name, and whatever the list wants on the right.",
  examples: [
    { key: :rows, title: "Rows in a flush card", layout: :full,
      description: "href: makes the title a link whose hit area is the whole row, while the actions stay " \
                   "clickable on their own. mono: true for a filename." }
  ]
