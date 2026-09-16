# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :tabs,
  name: "Tabs",
  helper: "tabs",
  import: "unmagic/components/tabs",
  description: "A row of tabs: panels switched in the page with the ARIA tab pattern, or links to separate " \
               "pages rendered on the server.",
  examples: [
    { key: :panels, title: "Panels in the page", layout: :full,
      description: "Arrow keys, Home and End move between tabs. A disabled tab shows its reason, and with an " \
                   "id: the choice survives a reload." },
    { key: :links, title: "Links to separate pages",
      description: "Tabs with href: need no script; mark the current one active: true." }
  ]
