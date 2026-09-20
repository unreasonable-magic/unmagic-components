# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :disclosure,
  name: "Disclosure",
  group: "Overlays",
  new: true,
  helper: "disclosure",
  import: nil,
  description: "A summary that folds a panel open, on <details>, and accordion, a run of them with one open at " \
               "a time through the platform's own <details name>. No script.",
  examples: [
    { key: :disclosures, title: "Disclosures",
      description: "A leading chevron turns as it opens. summary takes markup for a badge beside the title." },
    { key: :accordion, title: "An exclusive accordion", layout: :full,
      description: "exclusive: true lets one item open at a time; chevrons trail and turn down." }
  ]
