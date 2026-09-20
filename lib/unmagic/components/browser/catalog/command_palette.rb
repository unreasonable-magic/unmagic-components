# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :command_palette,
  name: "Command palette",
  group: "Navigation",
  new: true,
  helper: "command_palette",
  import: "unmagic/components/command_palette",
  description: "A dialog with a search box over every command in the app, opened with ⌘K. Each command holds " \
               "a real link or button_to form, so frames and confirms work as they do anywhere; more commands " \
               "arrive from src: as you type.",
  examples: [
    { key: :palette, title: "Open it", server: true,
      description: "Press the shortcut, or the button. Type \"kiln\" for a remote result." }
  ]
