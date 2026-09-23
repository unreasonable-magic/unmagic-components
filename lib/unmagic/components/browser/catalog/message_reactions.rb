# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message_reactions,
  name: "Reactions",
  group: "Messaging",
  helper: "message_reactions",
  new: true,
  description: "The emoji people have put on a message, each with its count and pressed when you're among them, " \
               "and a button to add one. Forms, so toggling one is a request your app already handles.",
  examples: [
    { key: :pills, title: "Pills and the add button",
      description: "Each pill posts to toggle itself; the pressed one is yours. The add button opens whatever " \
                   "picker you wire it to, here a native popover." },
    { key: :message, title: "Under a message", layout: :full,
      description: "m.reactions { |r| … } builds them in place, under the body." }
  ]
