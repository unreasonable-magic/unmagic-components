# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :image_crop,
  name: "Image Crop",
  group: "Data display",
  helper: "image_crop",
  import: "unmagic/components/image_crop",
  description: "Crop images locally with pointer and keyboard controls.",
  examples: [
    { key: :basic, title: "Freeform crop", layout: :full },
    { key: :square, title: "Square crop", layout: :full },
    { key: :circle, title: "Circular avatar", layout: :full }
  ]
