# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :text_highlights,
  name: "Text highlights",
  group: "Data display",
  helper: "text_highlights",
  import: nil,
  new: true,
  description: "Passages of a text marked like a highlighter pen: a word, a sentence, or everything from one quote " \
               "to another, each in its own colour. Found by what they say, marked on the server as <mark>s.",
  examples: [
    { key: :colors, title: "Words, sentences and colours",
      description: "A string is yellow; a Hash takes color:. Case, curly quotes and runs of whitespace don't have to " \
                   "match what's written." },
    { key: :ranges, title: "From one quote to another",
      description: "from: and to: mark everything between them, so a long passage needs only its ends. A later " \
                   "highlight wins where two overlap." },
    { key: :markup, title: "Across markup",
      description: "Given HTML, a highlight can run across a link or from one paragraph into the next; each piece " \
                   "is its own mark." }
  ]
