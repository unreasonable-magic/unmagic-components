# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :image_color_picker,
  name: "Image Color Picker",
  group: "Data display",
  helper: "image_color_picker",
  import: "unmagic/components/image_color_picker",
  description: "Pick a pixel from an image into a form field.",
  examples: [
    { key: :basic, title: "Sample a color", layout: :full }
  ]
