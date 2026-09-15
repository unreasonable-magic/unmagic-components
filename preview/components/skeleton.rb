# frozen_string_literal: true

ComponentsPreview::Catalog.component :skeleton,
  name: "Skeleton",
  helper: "skeleton",
  import: nil,
  description: "Blocks out an interface while it loads. Shapes take their size from what they stand in for, " \
               "and screen readers hear one \"Loading…\" instead of every shape. Each example sits beside the " \
               "real thing, so a difference in size shows at a glance.",
  examples: [
    { key: :blocking_out, title: "Blocking out your own layout", layout: :full,
      description: "skeleton yields s.text, s.circle, s.block and s.button to arrange with your own markup." },
    { key: :text_and_button, title: "skeleton_text and skeleton_button", layout: :full,
      description: "A text line fills one line of its font; a button shape is a real button's height." },
    { key: :page_header, title: "page_header skeleton: true", layout: :full },
    { key: :detail_list, title: "detail_list skeleton: true", layout: :full },
    { key: :card, title: "card skeleton: true", layout: :full }
  ]
