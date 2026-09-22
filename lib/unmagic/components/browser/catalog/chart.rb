# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :chart,
  name: "Chart",
  group: "Data display",
  helper: "chart",
  import: nil,
  description: "A chart drawn as inline SVG, no script: columns over a set of labels, stacked where there is more " \
               "than one series, or a line over time. Every column answers to hover, and the same numbers sit " \
               "under it as a table for anybody who can't or won't.",
  examples: [
    { key: :columns, title: "Stacked columns over days", layout: :full,
      description: "One { label:, values: } per series, values keyed by the label. format: says how every number " \
                   "reads; a total: shows in the legend." },
    { key: :line, title: "A line over time", layout: :full,
      description: "type: :line for a reading that's always there. A nil value is a gap the line doesn't bridge, " \
                   "and the newest reading gets a dot. max: pins the top of the axis." },
    { key: :narrow, title: "Three abreast", layout: :full,
      description: "width: is the drawing's own width; it scales to its box, so a narrow one keeps a readable axis." }
  ]
