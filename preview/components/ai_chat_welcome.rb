# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_welcome,
  name: "Welcome",
  group: "AI chat",
  helper: "ai_chat_welcome",
  import: "unmagic/components/ai_chat",
  description: "What an empty conversation says, and suggestions that start one. A good suggestion is runnable, " \
               "naming the reader's own data where there is some.",
  examples: [
    { key: :suggestions, title: "With suggestions", layout: :full,
      description: "Pressing one fills the composer below and sends it; the last only fills it." }
  ]
