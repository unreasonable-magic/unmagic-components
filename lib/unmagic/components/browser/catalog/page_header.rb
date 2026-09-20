# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :page_header,
  name: "Page header",
  group: "Layout",
  new: true,
  helper: "page_header",
  import: nil,
  description: "The top of a page: a back link, the title with its badges, a description, and the page's " \
               "actions on the right.",
  examples: [
    { key: :default, title: "Back link, badges and actions", layout: :full },
    { key: :with_leading, title: "With something before the title", layout: :full,
      description: "header.leading takes markup for an avatar or icon; title and description take blocks too." }
  ]
