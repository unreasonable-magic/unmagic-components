# frozen_string_literal: true

module Unmagic
  module Components
    module Renderers
      # The pager a table draws under itself, over a Pagy object or anything that
      # speaks the parts of Pagy's API it needs. Pagy is an optional dependency:
      # the default resolver looks for the controller's @pagy, and an app without
      # Pagy simply never renders a pager. The drawing is Pagination's.
      module Pagination
        class << self
          def default
            ->(view, pagy:, turbo_frame: nil) { render(view, pagy: pagy, turbo_frame: turbo_frame) }
          end

          def default_pagy_for
            method(:resolve).to_proc
          end

          # A count-aware collection (search results reporting #found) can build its
          # own pagy, which forces a lazy collection only on the render that shows
          # it. Anything else falls back to whatever the action assigned.
          def resolve(view, collection)
            if defined?(::Pagy) && collection.respond_to?(:found) && view.respond_to?(:pagy, true)
              view.send(:pagy, :offset, collection, count: collection.found, limit: collection.per_page).first
            else
              view.instance_variable_get(:@pagy)
            end
          end

          def render(view, pagy:, turbo_frame: nil)
            Components::Pagination.new(view, pagy, turbo_frame: turbo_frame).render
          end
        end
      end
    end
  end
end
