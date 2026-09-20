# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :toggle,
  name: "Toggle",
  group: "Forms",
  new: true,
  helper: "toggle",
  import: "unmagic/components/toggle",
  description: "A button that is on or off, and toggle_group, a run of them joined into a segmented control a " \
               "form submits. Native radios and checkboxes drawn as buttons, so the arrow keys move the choice " \
               "and no script is needed.",
  examples: [
    { key: :toggles, title: "Toggles",
      description: "Without a name: a button whose aria-pressed the script flips. With one, a checkbox drawn as " \
                   "a button, submitted with the form." },
    { key: :groups, title: "Toggle groups",
      description: "One of many as radios, several with multiple: true as checkboxes. On a narrow screen the " \
                   "run scrolls sideways." }
  ]
