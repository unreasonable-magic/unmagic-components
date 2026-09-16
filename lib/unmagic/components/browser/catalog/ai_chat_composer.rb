# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_composer,
  name: "Composer",
  group: "AI chat",
  helper: "ai_chat_composer",
  import: "unmagic/components/ai_chat",
  description: "The box a person types into, and the one button at the end of it: Send, or Stop while a turn runs. " \
               "Only the button changes with the turn's state, so a half-typed draft always survives.",
  examples: [
    { key: :states, title: "Every state", layout: :full,
      description: "Idle, running, stopping, and waiting on a question above. Enter sends, Shift+Enter makes a new " \
                   "line, and Enter does nothing without Send." },
    { key: :parts, title: "With controls", layout: :full,
      description: "attach and actions put controls in the box." }
  ]
