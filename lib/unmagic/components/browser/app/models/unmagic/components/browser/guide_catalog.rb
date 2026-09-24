# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # What the gem adds to Rails beyond its components (stream actions, the
      # modal, flash toasts, the confirm dialog, the form builder) and how its CSS
      # works. One page each, written as a guide rather than a gallery. components: are the catalog
      # pages that show the feature live.
      module GuideCatalog
        Guide = Data.define(:slug, :name, :description, :category, :components)

        GUIDES = [
          Guide.new(slug: "turbo_streams", name: "Turbo Stream actions",
            description: "turbo_stream.toast and turbo_stream.stream_markdown, and an upsert action that merges append and replace.",
            category: "Turbo", components: %w[toast streaming_markdown ai_chat]),
          Guide.new(slug: "modal_forms", name: "Modal forms",
            description: "One shared modal any link can load a form into, and a responder that saves and repaints the page once.",
            category: "Turbo", components: %w[dialog]),
          Guide.new(slug: "flash_toasts", name: "Flash messages",
            description: "Your controllers' flash, shown as toasts, with no change to how you set it.",
            category: "Turbo", components: %w[toast]),
          Guide.new(slug: "confirm", name: "Confirm dialogs",
            description: "data-turbo-confirm, answered by a dialog in the components' own chrome instead of window.confirm.",
            category: "Turbo", components: %w[confirm]),
          Guide.new(slug: "optimistic", name: "Optimistic updates",
            description: "Draw what a form submitted before the server answers, then let the server's element take its place.",
            category: "Turbo", components: %w[ai_chat ai_chat_composer]),
          Guide.new(slug: "form_builder", name: "Form builder",
            description: "Labels, hints, errors and styled controls from form_with, and a submit button that says what it's doing.",
            category: "Forms and settings", components: %w[forms combobox]),
          Guide.new(slug: "configuration", name: "Configuration",
            description: "The seams the components render through, for an app with its own empty states, pager or styles.",
            category: "Forms and settings", components: %w[table pagination code_view]),
          Guide.new(slug: "css", name: "How the CSS works",
            description: "One Tailwind source file your own build compiles, in the components layer, coloured from your palette.",
            category: "CSS", components: %w[card button]),
          Guide.new(slug: "class_names", name: "Class names",
            description: "BEM with a PascalCase block, every class prefixed, and state read from ARIA and data attributes.",
            category: "CSS", components: %w[tabs tooltip]),
          Guide.new(slug: "variables", name: "Colours and variables",
            description: "The theme variables the styles read from yours, and the few --unmagic- variables of their own.",
            category: "CSS", components: %w[chart toast scroll_area]),
          Guide.new(slug: "using_the_styles", name: "Using the styles",
            description: "The classes and helpers meant for your own markup: buttons, form controls, prose, knobs and variants.",
            category: "CSS", components: %w[button forms sortable_list chart]),
          Guide.new(slug: "small_screens", name: "Small screens and access",
            description: "What the CSS does for touch, phones, reduced motion, forced colours and keyboard focus.",
            category: "CSS", components: %w[dialog table menu])
        ].freeze

        def self.all = GUIDES
        def self.grouped = all.group_by(&:category)
        def self.find(slug) = all.find { |guide| guide.slug == slug }
      end
    end
  end
end
