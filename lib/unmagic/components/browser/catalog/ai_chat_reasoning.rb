# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_reasoning,
  name: "Reasoning",
  group: "AI chat",
  helper: "ai_chat_reasoning",
  description: "The model's thinking, collapsed above the reply it led to. Shut by default, and there for when a " \
               "reply is wrong and the working-out is the first place anyone looks.",
  examples: [
    { key: :settled, title: "Settled",
      description: "duration: titles it with how long the model thought." },
    { key: :thinking, title: "Still thinking",
      description: "streaming: true says so, with a spinner that pulses instead of turning under reduced motion." }
  ]
