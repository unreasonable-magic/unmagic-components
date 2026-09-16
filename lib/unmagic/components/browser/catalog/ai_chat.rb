# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat,
  name: "Conversation",
  group: "AI chat",
  helper: "ai_chat",
  import: "unmagic/components",
  description: "The root of the AI chat components: the scrolling region a conversation's turns are rendered into, " \
               "and the spacing between them. It follows new content while you're at the bottom, stops when you " \
               "scroll up, and offers a way back.",
  examples: [
    { key: :conversation, title: "A whole conversation", layout: :full,
      description: "Every piece together: a question, reasoning, a run of tool calls with one still going, a reply " \
                   "that quotes a record and proposes something, a permission request, and the plan and workspace " \
                   "beside it. Scroll up inside it to see the jump-to-latest button." },
    { key: :live, title: "Send a message", layout: :full,
      description: "The composer posts for real. The question is drawn at once, dimmed, until the server confirms " \
                   "it under the same id; the reply then streams in and settles. Press Stop mid-reply to freeze it." },
    { key: :welcome, title: "An empty conversation", layout: :full,
      description: "chat.welcome shows until the first entry arrives." }
  ]
