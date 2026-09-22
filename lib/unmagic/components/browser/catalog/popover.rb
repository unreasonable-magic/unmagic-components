# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :popover,
  name: "Popover",
  group: "Overlays",
  helper: "popover",
  import: "unmagic/components/popover",
  description: "A small panel of content behind a trigger: a form to rename something, a card about a person. " \
               "In the top layer, placed against the trigger, with light dismiss; a sheet along the bottom on " \
               "a narrow screen.",
  examples: [
    { key: :form, title: "A form in a popover",
      description: "The label is the trigger; title: heads the panel and names it; footer holds the submit." },
    { key: :card, title: "A trigger of your own",
      description: "popover.trigger { … } puts an avatar in place of the text button. placement: :top opens " \
                   "upward when there's room." }
  ]
