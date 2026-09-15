# frozen_string_literal: true

ComponentsPreview::Catalog.component :callout,
  name: "Callout",
  helper: "callout",
  import: nil,
  description: "A tinted note stating the state of something in place: a health check, a warning above a form. " \
               "Each tone brings its own icon, so meaning never rests on colour alone.",
  examples: [
    { key: :tones, title: "Tones", layout: :full },
    { key: :neutral, title: "Neutral", layout: :full,
      description: "A neutral callout has no icon; icon: false drops it from the other tones too." }
  ]
