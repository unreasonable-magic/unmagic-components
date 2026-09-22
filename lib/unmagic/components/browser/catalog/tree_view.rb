# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :tree_view,
  name: "Tree view",
  group: "Navigation",
  helper: "tree_view",
  import: nil,
  description: "A nested, collapsible list of things inside other things: files, teams, a documentation " \
               "sidebar. Nested lists and <details>, so it works with Tab alone and no script.",
  examples: [
    { key: :files, title: "A file tree",
      description: "Three levels deep. The current file is aria-current, and every folder on its way is open; " \
                   "the others start shut." },
    { key: :teams, title: "Markup in a leaf",
      description: "A leaf's block takes markup, a badge here. meta: keeps a short reading whole at the end " \
                   "of the row while the label truncates." },
    { key: :no_guides, title: "Without guides",
      description: "guides: false drops the line beside each level. An empty branch says so." }
  ]
