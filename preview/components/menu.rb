# frozen_string_literal: true

ComponentsPreview::Catalog.component :menu,
  name: "Menu",
  helper: "menu",
  import: "unmagic/components/menu",
  description: "A dropdown of actions built on <details>. It closes on an outside click, Escape, choosing an " \
               "item, or a Turbo navigation, and arrow keys, Home and End move between items.",
  examples: [
    { key: :labelled, title: "With a label",
      description: "A text trigger with a chevron, lined up with the trigger's left edge." },
    { key: :actions, title: "Icon trigger with actions",
      description: "With no label the trigger is a ⋮ button. Items can be button_to actions, and tone: :danger " \
                   "pairs with a confirm." }
  ]
