# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :progress,
  name: "Progress",
  group: "Data display",
  new: true,
  helper: "progress",
  import: nil,
  description: "A bar filled to a fraction of the way, in a tone and a size, or sweeping while the size of the " \
               "job is still unknown.",
  examples: [
    { key: :values, title: "Values, tones and sizes", layout: :full },
    { key: :indeterminate, title: "Indeterminate", layout: :full,
      description: "With no value the bar sweeps; under reduced motion it pulses in place." }
  ]
