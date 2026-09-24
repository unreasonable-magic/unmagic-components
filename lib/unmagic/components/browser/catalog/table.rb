# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :table,
  name: "Table",
  group: "Data display",
  helper: "table_for",
  import: nil,
  description: "Declarative index tables in the spirit of form_for: describe the columns, and the table " \
               "draws the chrome — sortable headers, empty states, companion rows and pagination.",
  examples: [
    { key: :sortable, title: "Sortable, numeric and aligned", layout: :full,
      description: "Click a sortable header to toggle ?sort and ?direction. The note under Ada is a companion row." },
    { key: :empty, title: "Empty", layout: :full },
    { key: :deferred, title: "Deferred", layout: :full,
      description: "The first render never touches the collection. Reload to watch the skeleton swap for " \
                   "the rows without the columns shifting." },
    { key: :deferred_shapes, title: "Deferred, with skeleton shapes", layout: :full,
      description: "Each column declares its skeleton: — :item, :badge, :icon, or a lambda given the skeleton " \
                   "builder — so the skeleton rows are the height and shape of the rows that replace them." },
    { key: :table_tag, title: "A static table from plain data", layout: :full }
  ]
