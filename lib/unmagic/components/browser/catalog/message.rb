# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message,
  name: "Message",
  group: "Messaging",
  helper: "message",
  new: true,
  description: "One message: who sent it, when, what it says, what came with it and what happened to it. Three " \
               "looks from one markup: a bubble for a chat, a row for a channel, an email in a card.",
  examples: [
    { key: :variants, title: "Three variants", layout: :full,
      description: "The same message as a bubble, a row and an email. Only the variant class differs." },
    { key: :bubbles, title: "Theirs and yours", layout: :full,
      description: "own: true puts a bubble on the right. continued: true drops the name and avatar, keeps the " \
                   "avatar's column and squares the joined corner." },
    { key: :statuses, title: "Statuses", layout: :full,
      description: "m.status with each state: a word and a glyph, coloured only for read and failed, and dimmed " \
                   "while sending. at: adds the moment." },
    { key: :parts, title: "Every part", layout: :full,
      description: "A row with a meta line, a quoted reply, attachments, reactions, an edited mark, a footer of your " \
                   "own and actions. Parts take a builder when their block takes an argument." },
    { key: :email, title: "Collapsed and open", layout: :full,
      description: "collapsible: true folds an email into a details whose summary is the header and a line of the " \
                   "body; open: false starts it shut." }
  ]
