# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message_actions,
  name: "Actions",
  group: "Messaging",
  helper: "message_actions",
  import: "unmagic/components/toolbar",
  new: true,
  description: "The controls on a message: reply, react, copy, edit, delete, a menu of more. A toolbar with one " \
               "Tab stop, shown on hover or focus and never hidden from the keyboard. ai_chat_action_bar is the " \
               "same thing under its old name.",
  examples: [
    { key: :hover, title: "On hover, and on focus", layout: :full,
      description: "Hover the row, or Tab into it: the bar floats over its corner. Left and Right move between " \
                   "the controls." },
    { key: :always, title: "Always shown",
      description: "reveal: :always. A copy button, links, a form with a confirmation, and a menu through bar.control." }
  ]
