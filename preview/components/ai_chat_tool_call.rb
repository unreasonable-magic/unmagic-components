# frozen_string_literal: true

ComponentsPreview::Catalog.component :ai_chat_tool_call,
  name: "Tool call",
  group: "AI chat",
  helper: "ai_chat_tool_call",
  description: "One reach for a tool, from the ask to the answer, as a row. A run of them is joined by a line into a " \
               "timeline, because four calls in one breath are one stretch of work, not four events.",
  examples: [
    { key: :run, title: "A run of calls", layout: :full,
      description: "Rows join up, counting the hidden gap markers between them. A done call's glyph says what it was " \
                   "about." },
    { key: :states, title: "Every state", layout: :full,
      description: "Queued, running (with a live clock and progress), waiting on a person, done, and failed." },
    { key: :made, title: "What a call made", layout: :full,
      description: "made keeps the output outside the fold, with the line running beside it." }
  ]
