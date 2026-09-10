# frozen_string_literal: true

module Unmagic
  module Components
    module Renderers
      # The blank slate a table falls back to when its collection is empty.
      module EmptyState
        class << self
          def default
            method(:render).to_proc
          end

          # Extra options from `table.empty` are for a host's own renderer; the
          # built-in one takes only a class.
          def render(view, content, **options)
            view.tag.div(content, class: view.class_names("UnmagicEmptyState", options[:class]))
          end
        end
      end
    end
  end
end
