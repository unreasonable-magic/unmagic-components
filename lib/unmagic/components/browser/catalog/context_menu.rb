# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :context_menu,
  name: "Context menu",
  group: "Navigation",
  helper: "context_menu",
  import: "unmagic/components/menu",
  description: "The same panel as menu, opened at the pointer on a right-click or a long press on the element " \
               "it is for, or at its corner on Shift+F10. The element can sit anywhere, so a table row can " \
               "have one.",
  examples: [
    { key: :rows, title: "On table rows", layout: :full,
      description: "Right-click a row, or long-press it on a phone. Keep the actions reachable elsewhere too: " \
                   "without script the browser's own menu shows." }
  ]
