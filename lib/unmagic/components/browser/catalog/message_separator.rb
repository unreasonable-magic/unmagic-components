# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message_separator,
  name: "Separator",
  group: "Messaging",
  helper: "message_separator",
  new: true,
  description: "A line across a conversation saying when the messages after it were sent, or that they are new.",
  examples: [
    { key: :dates, title: "Dates and new messages", layout: :full,
      description: "A label prints as it is; time: is a date in the viewer's zone; unread: true marks where the " \
                   "new messages start." }
  ]
