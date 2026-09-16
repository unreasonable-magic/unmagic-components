# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_permission,
  name: "Permission",
  group: "AI chat",
  helper: "ai_chat_permission",
  description: "An agent asking to be allowed something, with the answer under the reasoning rather than in a dialog " \
               "that arrived without it. The ask comes first, in the tool's own name; the reasoning is its case.",
  examples: [
    { key: :waiting, title: "Asking", layout: :full,
      description: "Allow is the prominent, consequential choice; a second, wider grant is offered only when there's " \
                   "something to widen. Focus goes to the card, never to Allow." },
    { key: :answered, title: "Answered", layout: :full,
      description: "Granted, refused, and a request answered in the chat with nothing granted." }
  ]
