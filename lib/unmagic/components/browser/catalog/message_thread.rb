# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message_thread,
  name: "Thread",
  group: "Messaging",
  helper: "message_thread",
  import: "unmagic/components",
  new: true,
  description: "A conversation: the container its messages, separators and typing indicator sit in, spacing them " \
               "and, when it's live, giving a screen reader a log to follow. One family of message components " \
               "renders a chat between people, a channel, an email thread and an AI chat.",
  examples: [
    { key: :chat, title: "A chat between people", layout: :full,
      description: "Bubbles: theirs on the left with an avatar, yours on the right on the dark surface. continued: " \
                   "true joins a run from one sender; the last of yours carries its status; someone is typing." },
    { key: :channel, title: "A channel thread", layout: :full,
      description: "Rows with avatars, names and times. Hover a row for its actions; a continued row shows its time " \
                   "in the gutter. Reactions, a quoted reply, a reply count and an unread marker." },
    { key: :email, title: "An email conversation", layout: :full,
      description: "Letters in cards. Older messages are collapsed to their header and a line of the body, and open " \
                   "on a click or Enter. Reply and Forward are text buttons through bar.control." },
    { key: :assistant, title: "An AI chat", layout: :full,
      description: "A bubble of your own and an unbubbled row for the reply, from the same helper. ai_chat_message " \
                   "is this with streaming, a thinking spinner and the optimistic template on top." }
  ]
