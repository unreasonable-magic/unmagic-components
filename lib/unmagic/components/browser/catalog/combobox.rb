# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :combobox,
  name: "Combobox",
  group: "Forms",
  helper: "combobox",
  import: "unmagic/components/combobox",
  description: "A text input that filters a list of options, choosing one or several, with the list served " \
               "from a collection or fetched as you type. The ARIA combobox pattern, with the list in the top " \
               "layer so nothing clips it.",
  examples: [
    { key: :single, title: "One of a list", layout: :full,
      description: "Type to filter; arrow keys move, Enter chooses, Escape restores. The value is a hidden " \
                   "input, so a form submitted before script loads keeps it." },
    { key: :multiple, title: "Several, as chips", layout: :full,
      description: "multiple: true submits name[] with a chip per choice; Backspace on an empty input removes " \
                   "the last." },
    { key: :remote, title: "Fetched as you type", server: true, layout: :full,
      description: "src: points at an action answering ?q= with combobox_results, rendered into the list's " \
                   "frame. Try \"ada\" or \"hopper\"." }
  ]
