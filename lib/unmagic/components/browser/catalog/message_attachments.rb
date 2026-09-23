# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :message_attachments,
  name: "Attachments",
  group: "Messaging",
  helper: "message_attachments",
  import: "unmagic/components/dropzone",
  new: true,
  description: "The files that came with a message, as tiles with a glyph or a thumbnail, the name and the size. " \
               "ai_chat_dropzone takes files before they're sent and draws the same tile for each.",
  examples: [
    { key: :sent, title: "On a message", layout: :full,
      description: "Tiles with a thumbnail or a glyph, aligned to the message's side, above a bubble." },
    { key: :dropzone, title: "Dropping and pasting", layout: :full,
      description: "ai_chat_dropzone around a composer: drag a file over the box, paste one into the field, or use " \
                   "the paperclip. Remove one with its ×." }
  ]
