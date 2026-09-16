# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_proposal,
  name: "Proposal",
  group: "AI chat",
  helper: "ai_chat_proposal",
  description: "An offer the agent made in passing — a fact it inferred, something it suggests tracking — with its " \
               "actions while pending, settling into a quiet decided state. Unlike a request, it doesn't stop the " \
               "work.",
  examples: [
    { key: :inline, title: "Inside a reply", layout: :full,
      description: "Quieter than a card, so it doesn't read as the end of the reply." },
    { key: :decided, title: "Decided", layout: :full,
      description: "Accepted, and dismissed (dimmed)." }
  ]
