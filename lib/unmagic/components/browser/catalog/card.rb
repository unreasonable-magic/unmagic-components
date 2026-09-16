# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :card,
  name: "Card",
  helper: "card",
  import: nil,
  description: "A bordered surface for a section of a page, with an optional title, header actions and a " \
               "tinted footer.",
  examples: [
    { key: :actions_and_footer, title: "Title, actions and footer" },
    { key: :link, title: "A card that is one link",
      description: "href: makes the whole card a link, for a row that opens a record. Nothing inside should be " \
                   "a link or button of its own." },
    { key: :flush_table, title: "Flush, with a table", layout: :full,
      description: "flush: true drops the body's padding, so a table runs edge to edge." }
  ]
