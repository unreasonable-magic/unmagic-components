# frozen_string_literal: true

ComponentsPreview::Catalog.component :sortable_list,
  name: "Sortable list",
  helper: "sortable_list",
  import: "unmagic/components/sortable",
  description: "A list whose items can be dragged, or moved with the keyboard, into a new place — here or in another " \
               "list sharing its namespace. A drop fires unmagic-sortable:move and posts the move.",
  examples: [
    { key: :handles, title: "With handles",
      description: "Only the grip drags, and the grip is the keyboard stop. Nothing is posted here, so the event is " \
                   "shown below the list." },
    { key: :grid, title: "A wrapping grid", layout: :full,
      description: "orientation: :grid. The drop slot follows reading order, and every arrow key moves." },
    { key: :connected, title: "Two lists, one namespace", layout: :full,
      description: "Items move between lists that share a namespace. Left and Right move a held item across." }
  ]
