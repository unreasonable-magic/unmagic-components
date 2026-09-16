# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_slash_menu,
  name: "Slash menu",
  group: "AI chat",
  helper: "ai_chat_slash_menu",
  import: "unmagic/components/slash_menu",
  description: "Commands offered on a slash. Every command is rendered and the typing filters them, so what can be " \
               "offered is only ever what exists. Focus stays in the field; the menu takes the arrow keys, Enter and " \
               "Tab while open.",
  examples: [
    { key: :composer, title: "In a composer", layout: :full,
      description: "Type / in the box. Try /in, then Enter." }
  ]
