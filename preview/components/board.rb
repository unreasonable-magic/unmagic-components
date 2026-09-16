# frozen_string_literal: true

ComponentsPreview::Catalog.component :board,
  name: "Board",
  helper: "board",
  import: "unmagic/components",
  description: "A Trello-style board: columns of cards, both reorderable by pointer or keyboard, with a way to add " \
               "to each. Drops post to one endpoint (unmagic-sortable's), and the page morphs to the saved order.",
  examples: [
    { key: :live, title: "A working board", layout: :full,
      description: "Drag cards within and between columns, drag a column by its header, or add a card or a list. " \
                   "It's saved in your session. On a phone, press and hold a card or a column's header to lift it. " \
                   "With the keyboard: Tab to a card or a column's grip, Space to pick it up, arrows to move it, " \
                   "Space to drop, Escape to cancel." },
    { key: :handles, title: "Cards with handles", layout: :full,
      description: "A sortable_handle in a card makes only the grip drag it, so the rest of the card stays a link, " \
                   "and on a touch screen the grip drags at once, without the long press." }
  ]
