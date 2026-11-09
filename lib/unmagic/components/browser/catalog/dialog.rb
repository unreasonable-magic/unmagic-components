# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :dialog,
  name: "Dialog",
  group: "Overlays",
  helper: "dialog",
  import: "unmagic/components/modal",
  description: "Native <dialog>s sharing one panel: a titled header with a close button, the body, and an " \
               "optional footer. Load one from the server into the shared modal, or put one on the page.",
  examples: [
    { key: :modal, title: "Loaded into the shared modal", server: true, layout: :full,
      description: "Clear the name and save to see a 422 keep the dialog open. A good save closes it in the " \
                   "same render as the morph refresh. Slow shows the skeleton; Forbidden shows the error panel." },
    { key: :dialog_tag, title: "Already on the page",
      description: "dialog_tag and dialog_button open a dialog with no request." },
    { key: :long, title: "A long form",
      description: "The body scrolls inside a dialog taller than the screen, with the title and footer in view. " \
                   "The combobox at the bottom opens over the scrolling body, not inside it." },
    { key: :drawer, title: "A drawer along the edge",
      description: "side: :end (or :start) opens the panel as a drawer the full height of the screen, its body " \
                   "scrolling and its footer pinned. On a phone every dialog is a sheet from the bottom." }
  ]
