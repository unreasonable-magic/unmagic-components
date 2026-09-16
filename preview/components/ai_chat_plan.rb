# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_plan,
  name: "Plan",
  group: "AI chat",
  helper: "ai_chat_plan",
  description: "The checklist an agent is working through, redrawn in place as it goes. A done step recedes and the " \
               "one being worked stands up, so a long plan reads as a position rather than a list.",
  examples: [
    { key: :states, title: "A plan under way",
      description: "Waiting is the one step in colour: the only state that won't move on its own." },
    { key: :empty, title: "Empty",
      description: "It still renders, so a broadcast has something to replace." }
  ]
