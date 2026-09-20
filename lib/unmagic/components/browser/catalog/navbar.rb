# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :navbar,
  name: "Navbar",
  group: "Navigation",
  new: true,
  helper: "navbar",
  import: "unmagic/components/navbar",
  description: "The bar across the top of an app: a brand, a run of links and the actions at the end. On a " \
               "narrow screen the links fold behind a menu button, with no script.",
  examples: [
    { key: :bar, title: "Brand, links and actions", layout: :full,
      description: "collapse: :md folds the links below 48rem; open the menu button at a phone width." }
  ]
