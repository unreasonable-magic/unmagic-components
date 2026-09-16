# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :toast,
  name: "Toast",
  helper: "flash_toasts",
  import: "unmagic/components/toasts",
  description: "Flashes and stream responses as toasts that dismiss themselves, pause while hovered or " \
               "focused, and survive Drive visits and morph refreshes.",
  examples: [
    { key: :flash, title: "From a flash, after a redirect", layout: :full,
      description: "Each button sets flash[type] and redirects back. Hover a toast to hold it open." },
    { key: :stream, title: "From a stream response",
      description: "turbo_stream.toast pops one without a redirect." },
    { key: :above_dialog, title: "Above an open dialog",
      description: "A toast streamed from a dialog shows above it, and times out even though the dialog " \
                   "makes it inert." }
  ]
