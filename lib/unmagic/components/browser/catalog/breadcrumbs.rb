# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :breadcrumbs,
  name: "Breadcrumbs",
  group: "Navigation",
  helper: "breadcrumbs",
  import: nil,
  description: "The trail of pages above this one: a labelled list of links with the current page last. On a " \
               "phone only the last two stay.",
  examples: [
    { key: :trail, title: "A trail",
      description: "crumbs.link takes link_to's arguments; crumbs.current is the page you're on." },
    { key: :header, title: "In a page header", layout: :full,
      description: "page_header's breadcrumbs part puts the trail where back: goes." }
  ]
