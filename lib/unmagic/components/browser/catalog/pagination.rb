# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :pagination,
  name: "Pagination",
  group: "Navigation",
  new: true,
  helper: "pagination",
  import: nil,
  description: "Links to the pages around this one, for anything that pages like Pagy: arrows either side, the " \
               "first and last pages, and a window around the current one. On a phone the numbers give way to " \
               "\"6 of 12\". It's what a table draws under itself.",
  examples: [
    { key: :pages, title: "Numbered pages", layout: :full,
      description: "window: is the pages either side of the current one. A gap stands in for the pages skipped." },
    { key: :arrows, title: "Arrows only",
      description: "A pager that only knows previous and next gets the arrows alone." }
  ]
