# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :image_zoom,
  name: "Image Zoom",
  group: "Data display",
  helper: "image_zoom",
  import: "unmagic/components/image_zoom",
  description: "Inspect an image in a keyboard-accessible lightbox.",
  examples: [
    { key: :basic, title: "Click to zoom", layout: :full },
    { key: :original, title: "Separate original", layout: :full }
  ]
