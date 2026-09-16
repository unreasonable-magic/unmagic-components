# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :button,
  name: "Button",
  helper: "button_classes",
  import: nil,
  description: "The class string for a button, so the look composes with link_to, button_to and form.submit " \
               "alike. Pick a variant for its weight and a size to sit beside other controls.",
  examples: [
    { key: :variants, title: "Variants",
      description: "Default, primary, ghost and danger. Danger keeps the default's shape; only the label and hover warn." },
    { key: :sizes, title: "Sizes",
      description: "Small, default and large, each matching an input of the same size." }
  ]
