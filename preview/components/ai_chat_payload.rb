# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_payload,
  name: "Payload",
  group: "AI chat",
  helper: "ai_chat_payload",
  description: "What went into a tool call or came back, to be read exactly as written. Structured data is laid out " \
               "a key to a line; the block scrolls, wraps, and colours through the host's highlighter via " \
               "config.code_block.",
  examples: [
    { key: :json, title: "Structured data", layout: :full,
      description: "A Hash, an Array, or a string holding JSON." },
    { key: :text, title: "Text, long", layout: :full,
      description: "Anything else stays text. It scrolls past a height without dragging the page, and is reachable " \
                   "by keyboard." }
  ]
