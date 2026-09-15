# frozen_string_literal: true

ComponentsPreview::Catalog.component :copy_button,
  name: "Copy button",
  helper: "copy_button",
  import: "unmagic/components/clipboard",
  description: "A button that copies text to the clipboard, showing a check for a moment once it has, and " \
               "announcing it to screen readers.",
  examples: [
    { key: :from_element, title: "Copy from an element",
      description: "from: copies the text of the element (or the value of the input) with that id, at the " \
                   "moment of the click, so the text isn't duplicated into an attribute." },
    { key: :with_label, title: "With a label",
      description: "A block replaces the icon button with your own content." }
  ]
