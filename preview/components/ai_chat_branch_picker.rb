# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_branch_picker,
  name: "Branch picker",
  group: "AI chat",
  helper: "ai_chat_branch_picker",
  description: "Walking between versions of a turn. It renders the position and follows links you supply; what a " \
               "branch is stays your application's business. One version renders nothing.",
  examples: [
    { key: :positions, title: "First, middle and last",
      description: "An end with nowhere to go is disabled, not a dead link." }
  ]
