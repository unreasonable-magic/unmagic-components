# frozen_string_literal: true

module Unmagic
  module Components
    module Renderers
      # The blank slate a table falls back to when its collection is empty, and
      # the one empty_state draws on its own.
      module EmptyState
        class << self
          def default
            method(:render).to_proc
          end

          # content is the line that says what's missing (or a whole block of
          # markup, as a table's empty text is); title: a heading above it, icon:
          # a glyph above that, and actions: the button that fixes it. Extra
          # options from `table.empty` are for a host's own renderer; the built-in
          # one takes a class.
          def render(view, content, title: nil, icon: nil, actions: nil, **options)
            view.tag.div(class: view.class_names("UnmagicEmptyState", options[:class])) do
              view.safe_join [
                (icon.is_a?(Symbol) ? Icons.svg(view, icon, class: "UnmagicEmptyState__icon") : icon),
                (view.tag.h3(title, class: "UnmagicEmptyState__title") if title.present?),
                (view.tag.div(content, class: "UnmagicEmptyState__text") if content.present?),
                (view.tag.div(actions, class: "UnmagicEmptyState__actions") if actions.present?)
              ].compact
            end
          end
        end
      end
    end
  end
end
