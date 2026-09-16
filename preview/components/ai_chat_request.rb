# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_request,
  name: "Request",
  group: "AI chat",
  helper: "ai_chat_request",
  description: "The agent asking something it can't work out itself, with the answers right there. It asks in " \
               "choices or with a form, and keeps its questions once answered — the question is most of what the " \
               "card is worth later.",
  examples: [
    { key: :choices, title: "Choices", layout: :full,
      description: "One question or several, single or multiple choice. A single choice is required." },
    { key: :form, title: "A form", layout: :full,
      description: "request.form takes your own fields; Decline skips validation." },
    { key: :answered, title: "Answered", layout: :full,
      description: "The options go and what was picked stays. Declined and cancelled cards dim." }
  ]
