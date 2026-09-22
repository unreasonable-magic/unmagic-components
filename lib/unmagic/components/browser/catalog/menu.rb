# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :menu,
  name: "Menu",
  group: "Navigation",
  helper: "menu",
  import: "unmagic/components/menu",
  description: "A dropdown of actions on the Popover API: the panel is in the top layer, so nothing clips it, and " \
               "it opens and closes without script. Arrow keys, Home and End move between items; on a narrow " \
               "screen it is a sheet along the bottom.",
  examples: [
    { key: :labelled, title: "With a label",
      description: "A text trigger with a chevron, lined up with the trigger's left edge." },
    { key: :actions, title: "Icon trigger with actions", server: true,
      description: "With no label the trigger is a ⋮ button. Items can be button_to actions, and tone: :danger " \
                   "pairs with a confirm." },
    { key: :parts, title: "Sections, icons and a disclosure",
      description: "section heads the items after it; icon: leads a label; item is a plain button for wiring; " \
                   "disclosure folds a small form out in place, so the whole exchange happens inside the panel." }
  ]
