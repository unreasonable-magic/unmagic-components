# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :spinner,
  name: "Spinner",
  group: "Data display",
  new: true,
  helper: "spinner",
  import: nil,
  description: "A ring that turns while something loads, with visible text beside it or a label read aloud " \
               "instead. It pulses rather than turning under reduced motion.",
  examples: [
    { key: :sizes, title: "Sizes and text",
      description: "Small, medium and large; visible text is the label, and label: false makes the ring decorative " \
                   "for a control that already says what is happening." }
  ]
