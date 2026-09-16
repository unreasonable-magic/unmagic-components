# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_citation,
  name: "Citation",
  group: "AI chat",
  helper: "ai_chat_citation",
  description: "A quotation of a record, rendered from the record rather than the model's paraphrase of it — so the " \
               "words are the real ones. The quote is escaped text, so neither the record nor the model can inject " \
               "markup.",
  examples: [
    { key: :quote, title: "A quoted message", layout: :full,
      description: "cite.avatar with no block draws the gem's avatar for the author." },
    { key: :compact, title: "A list of sources", layout: :full,
      description: "compact: true, one line each." }
  ]
