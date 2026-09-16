# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_action_bar,
  name: "Action bar",
  group: "AI chat",
  helper: "ai_chat_action_bar",
  import: "unmagic/components/toolbar",
  description: "The controls under a turn: copy it, run it again, edit it. A toolbar — one Tab stop, arrow keys " \
               "between controls — that shows on hover or focus, and always on touch screens.",
  examples: [
    { key: :hover, title: "On a reply", layout: :full,
      description: "Hover the reply, or Tab to it: the bar appears as it takes focus." },
    { key: :always, title: "Always shown",
      description: "reveal: :always." }
  ]
