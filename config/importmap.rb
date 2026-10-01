# frozen_string_literal: true

# Every component module pinned by name: "unmagic/components" imports them all, and
# "unmagic/components/<name>" imports one.
pin "unmagic/components", to: "unmagic/components.js", preload: true
pin_all_from File.expand_path("../app/assets/javascripts/unmagic/components", __dir__),
  under: "unmagic/components", preload: true

# Override the recursive component pins for the heavy, on-demand editor modules.
# Pin names alone do not download JavaScript; never modulepreload this subtree.
pin_all_from File.expand_path("../app/assets/javascripts/unmagic/components/code_editor", __dir__),
  under: "unmagic/components/code_editor", preload: false
