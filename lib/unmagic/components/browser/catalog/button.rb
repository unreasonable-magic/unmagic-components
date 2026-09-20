# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :button,
  name: "Button",
  group: "Forms",
  new: true,
  helper: "button",
  import: nil,
  description: "A button, a link that looks like one, or a button_to form, from one call; and button_classes, " \
               "the class string alone, for link_to, button_to and form.submit. Pick a variant for its weight and " \
               "a size to sit beside other controls.",
  examples: [
    { key: :variants, title: "Variants",
      description: "Default, primary, ghost and danger. Danger keeps the default's shape; only the label and hover warn." },
    { key: :sizes, title: "Sizes",
      description: "Small, default and large, each matching an input of the same size." },
    { key: :icons, title: "Icons, links and forms",
      description: "icon: leads the label; the :icon variant shows only the icon and keeps the label for a screen " \
                   "reader. href: makes a link, and with method: a button_to form." },
    { key: :states, title: "Loading, disabled and block",
      description: "loading: true disables the button and turns a spinner in the icon's place. A disabled link is " \
                   "marked and taken out of the tab order. block: true fills the width." },
    { key: :group, title: "Button groups",
      description: "button_group joins buttons edge to edge into one control; orientation: :vertical stacks them." }
  ]
