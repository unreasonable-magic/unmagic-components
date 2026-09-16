# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_attachments,
  name: "Attachments",
  group: "AI chat",
  helper: "ai_chat_attachments",
  import: "unmagic/components/dropzone",
  description: "Files on their way into a conversation: a drop zone around the page, chips on the composer for " \
               "what's attached and unsent, and tiles on the turn that sent them. Dragging is never the only way in.",
  examples: [
    { key: :dropzone, title: "Dropping and pasting", layout: :full,
      description: "Drag a file over the box, paste one into the field, or use the paperclip. Remove one with its ×." },
    { key: :sent, title: "On a sent turn", layout: :full,
      description: "Tiles with a thumbnail or a glyph, aligned to the turn." }
  ]
