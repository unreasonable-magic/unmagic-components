# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message_typing,
  name: "Typing",
  group: "Messaging",
  helper: "message_typing",
  new: true,
  description: "Someone is writing: three dots in a bubble, with the writer's name. Under reduced motion the " \
               "dots pulse instead of rising.",
  examples: [
    { key: :writers, title: "Named, with an avatar, and anonymous",
      description: "Reads as \"Ana Silva is typing\", or \"Typing\", to a screen reader." }
  ]
