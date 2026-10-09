# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :avatar,
  name: "Avatar",
  group: "Data display",
  helper: "avatar",
  description: "A person's or organisation's picture, falling back to initials on a fill picked from the name " \
               "(or a seed: such as an id) — the same colour on every page and every server.",
  examples: [
    { key: :sizes, title: "Sizes and fallbacks",
      description: "Five named sizes and a CSS length, with and without an image. A broken image shows the " \
                   "initials through it." },
    { key: :tints, title: "Tints",
      description: "The default fill: six tints from the name, so each person keeps their colour. fill: false " \
                   "is neutral." },
    { key: :fills, title: "Fills",
      description: "Avatar::Solid and Avatar::Gradient pick from the whole hue wheel, tuned by their arguments. " \
                   "Set one for the app as config.avatar_fill, or pass fill: for one avatar." },
    { key: :organizations, title: "People and organisations",
      description: "kind: reads initials as a person or an organisation: particles, mononyms, legal suffixes, " \
                   "and a three-character mark where the avatar has room." },
    { key: :group, title: "A group",
      description: "avatar_group stacks them, collapsing past max: into a counter that names the rest." }
  ]
