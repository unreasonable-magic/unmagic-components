# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_message,
  name: "Message",
  group: "AI chat",
  helper: "ai_chat_message",
  description: "One turn. A user's question is a bubble of plain text; an assistant's answer is unbubbled prose, " \
               "because a question is a remark and an answer is a document.",
  examples: [
    { key: :turns, title: "A question and an answer", layout: :full,
      description: "The assistant's body is the host's rendered HTML, styled by UnmagicProse." },
    { key: :states, title: "Thinking, stopped and empty", layout: :full,
      description: "streaming: true shows a spinner until the first token; final: true refuses later flushes; an " \
                   "empty settled turn is hidden." },
    { key: :parts, title: "Reasoning, actions and branches", layout: :full,
      description: "The parts a turn can carry, in the order they render. Hover the reply to see its actions." }
  ]
