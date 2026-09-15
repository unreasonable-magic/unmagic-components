# frozen_string_literal: true

ComponentsPreview::Catalog.component :detail_list,
  name: "Detail list",
  helper: "detail_list",
  import: nil,
  description: "A <dl> of a record's fields, laid out inline or stacked. A blank value renders as an em dash, " \
               "so call sites don't each need .presence || \"—\".",
  examples: [
    { key: :inline, title: "Inline", layout: :full,
      description: "Labels beside values. Notes is blank, so it shows an em dash." },
    { key: :stacked, title: "Stacked", layout: :full,
      description: "Small uppercase labels above values, two columns on wide screens." }
  ]
