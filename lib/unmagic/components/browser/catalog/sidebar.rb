# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :sidebar,
  name: "Sidebar",
  group: "Navigation",
  new: true,
  helper: "sidebar",
  import: "unmagic/components/sidebar",
  description: "The navigation down the side of an app: sections of links with icons and counts, a header and " \
               "a footer. One <nav> for both widths: a sheet from the edge below the breakpoint, inline above.",
  examples: [
    { key: :nav, title: "Sections, icons and counts", layout: :full,
      description: "Rendered here with collapse_below: :never so it is inline at every width; in a layout, " \
                   "the toggle opens it as a sheet on a phone." },
    { key: :sheet, title: "As a sheet",
      description: "collapse_below: :lg (the default) with a sidebar_toggle. Below 64rem the toggle opens the " \
                   "sheet; on this page it is always a sheet, so the toggle shows." }
  ]
