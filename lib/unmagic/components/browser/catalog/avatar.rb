# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :avatar,
  name: "Avatar",
  group: "Data display",
  helper: "avatar",
  description: "A person's or organisation's picture, falling back to initials on one of six tints picked from " \
               "the name — the same tint for the same name on every page and every server.",
  examples: [
    { key: :sizes, title: "Sizes and fallbacks",
      description: "Three sizes, with and without an image. A broken image shows the initials through it." },
    { key: :tints, title: "Tints",
      description: "The tint comes from the name, so each person keeps their colour. tint: false is neutral." },
    { key: :group, title: "A group",
      description: "avatar_group stacks them, collapsing past max: into a counter that names the rest." }
  ]
