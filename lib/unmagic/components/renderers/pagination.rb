# frozen_string_literal: true

module Unmagic
  module Components
    module Renderers
      # A prev/next pager over a Pagy object. Pagy is an optional dependency: the
      # default resolver looks for the controller's @pagy and the renderer bails
      # out unless the object it gets speaks the parts of Pagy's API it needs, so
      # an app without Pagy simply never renders a pager.
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
            return unless pageable?(pagy)
            return if pagy.previous.nil? && pagy.next.nil?

            data = ({ turbo_frame: turbo_frame, turbo_action: "advance" } if turbo_frame)

            view.tag.nav(class: "UnmagicPagination", "aria-label": "Pagination") do
              view.safe_join [
                link(view, pagy, :previous, "Previous", data),
                link(view, pagy, :next, "Next", data)
              ]
            end
          end

          private

          def pageable?(pagy)
            pagy.respond_to?(:previous) && pagy.respond_to?(:next) && pagy.respond_to?(:page_url)
          end

          def link(view, pagy, direction, label, data)
            if pagy.public_send(direction)
              view.link_to(label, pagy.page_url(direction), class: "UnmagicPagination__link", data: data)
            else
              view.tag.span(label, class: "UnmagicPagination__link", "aria-disabled": "true")
            end
          end
        end
      end
    end
  end
end
