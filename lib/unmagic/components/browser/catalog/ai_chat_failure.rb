# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_failure,
  name: "Failure",
  group: "AI chat",
  helper: "ai_chat_failure",
  description: "A turn that fell over, and what it fell over on. The sentence is for whoever asked; the diagnostics, " \
               "folded away, are for whoever works on the assistant.",
  examples: [
    { key: :full, title: "With details and a retry", layout: :full,
      description: "Render it below a turn's body, never in its place: a reply cut off at the context limit still " \
                   "has its answer above." },
    { key: :plain, title: "Just the sentence", layout: :full,
      description: "A turn that failed before anything was recorded." }
  ]
