# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :code_view,
  name: "Code view",
  group: "Data display",
  new: true,
  helper: "code_view",
  import: "unmagic/components/clipboard",
  description: "A block of source to read or copy: coloured with Rouge, wrapping long lines, with a copy button " \
               "that appears on hover and stays put on touch screens. Just the code; put it in a panel or a card " \
               "for a heading.",
  examples: [
    { key: :languages, title: "Any language Rouge knows", layout: :full,
      description: "language: names the lexer. Long lines wrap by default, and the copy button copies the " \
                   "source as written." },
    { key: :lines, title: "Numbered, and capped in height", layout: :full,
      description: "lines: true numbers the lines without putting the numbers in a copy. max_height: makes " \
                   "the block scroll, and a block that can scroll is focusable and named for a keyboard." },
    { key: :sideways, title: "Scrolling sideways instead", layout: :full,
      description: "wrap: false keeps every line on one line, for a table drawn in text or a command that " \
                   "must not break. copy: false drops the button." }
  ]
