# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :elapsed,
  name: "Elapsed",
  group: "Data display",
  helper: "elapsed_tag",
  import: "unmagic/components/elapsed",
  description: "A clock counting up from a moment the server named, or down to one. Work that takes a minute and " \
               "work that has hung look the same behind a spinner; a number that keeps moving is the difference.",
  examples: [
    { key: :running, title: "Counting up",
      description: "The server renders the current reading and the element keeps it moving, a second at a time." },
    { key: :countdown, title: "Counting down",
      description: "direction: :down stops at zero and fires unmagic-elapsed:end." }
  ]
