# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :local_time,
  name: "Local time",
  group: "Data display",
  helper: "local_time_tag",
  import: "unmagic/components/time",
  description: "A timestamp shown in the viewer's own locale and time zone, formatted by the browser with Intl. " \
               "Until the element upgrades, the server's rendering in Time.zone shows instead.",
  examples: [
    { key: :relative, title: "Relative, keeping itself current", layout: :full,
      description: "format: :relative stays current on a shared timer; compact: true shortens it to \"5m\"." },
    { key: :absolute, title: "Absolute, in the viewer's zone", layout: :full }
  ]
