# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :panel,
  name: "Panel",
  group: "Layout",
  helper: "panel",
  import: "unmagic/components/tabs",
  description: "A card with switcher buttons across its top bar and the open one's content below: a README beside " \
               "the brief, a file's source beside its preview. Tabs switch in the page, or each is a page of its own.",
  examples: [
    { key: :switching, title: "Tabs switched in the page", layout: :full,
      description: "The same tabs as tabs, in a bar: icon: leads each label, and the row scrolls sideways on a " \
                   "narrow screen with the open tab brought into view." },
    { key: :links, title: "Tabs that are pages of their own", layout: :full,
      description: "With href: the bar is links and the block is the body, drawn by the server for the open one. " \
                   "flush: true lets the content run to the edges, as a code view wants to." }
  ]
