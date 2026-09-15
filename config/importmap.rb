# frozen_string_literal: true

# Every component module pinned by name: "unmagic/components" imports them all, and
# "unmagic/components/<name>" imports one.
pin "unmagic/components", to: "unmagic/components.js", preload: true
pin_all_from File.expand_path("../app/assets/javascripts/unmagic/components", __dir__),
  under: "unmagic/components", preload: true
