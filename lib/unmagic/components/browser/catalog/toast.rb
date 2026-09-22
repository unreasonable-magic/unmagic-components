# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :toast,
  name: "Toast",
  group: "Overlays",
  helper: "flash_toasts",
  import: "unmagic/components/toasts",
  description: "Flashes and stream responses as toasts that dismiss themselves, pause while hovered or " \
               "focused, and survive Drive visits and morph refreshes.",
  examples: [
    { key: :flash, title: "From a flash, after a redirect", server: true, layout: :full,
      description: "Each button sets flash[type] and redirects back. Hover a toast to hold it open." },
    { key: :stream, title: "From a stream response", server: true,
      description: "turbo_stream.toast pops one without a redirect." },
    { key: :content, title: "Title, icon and action", server: true,
      description: "A heading adds context; actions are ordinary Rails buttons or links." },
    { key: :tones, title: "Tones", server: true, layout: :full,
      description: "Good, warn, bad and info, plus neutral, accent and inverted surfaces." },
    { key: :positions, title: "Six positions", server: true, layout: :full,
      description: "Place each toast independently. Start and end follow the reading direction." },
    { key: :duration, title: "Duration and sticky toasts", server: true, layout: :full,
      description: "Mix timed and sticky messages. A duration of 0 waits for the dismiss button." },
    { key: :width, title: "Widths", server: true,
      description: "Short, long or a pixel width; each stays within the screen on a phone." },
    { key: :actions, title: "Action layouts", server: true,
      description: "Give horizontal actions room with width: :long, or place them below with layout: :vertical. Narrow toasts stack automatically. close_button: false hides the × when a Dismiss action is provided." },
    { key: :leading, title: "Custom leading content", server: true,
      description: "Use the leading slot for an avatar or other context instead of the default icon." },
    { key: :custom, title: "Custom content", server: true,
      description: "Capture a body slot for a composed announcement. The close button stays available." },
    { key: :boundaries, title: "Inside a panel", server: true, layout: :full,
      description: "A named, scoped mount contains notifications within a positioned panel." },
    { key: :above_dialog, title: "Above an open dialog", server: true,
      description: "A toast streamed from a dialog shows above it, and times out even though the dialog " \
                   "makes it inert." }
  ]
