# frozen_string_literal: true

require "bigdecimal"

module Unmagic
  module Components
    # Drag-and-drop ordering: a list whose items can be dragged, or moved with the
    # keyboard, and dropped in a new place, here or in another list that shares its
    # namespace. See ActionViewHelpers#sortable_list.
    module Sortable
      ORIENTATIONS = %i[vertical horizontal grid].freeze

      # What the element says to a screen reader as an item is picked up, moved,
      # dropped or put back. {item}, {list}, {position} and {count} are filled in by
      # the element as it goes.
      ANNOUNCEMENTS = {
        instructions: "Press Space to pick up. While holding it, use the arrow keys to move it, Space to drop it, " \
                      "and Escape to cancel.",
        picked: "Picked up {item}. Position {position} of {count} in {list}.",
        moved: "{item} moved to position {position} of {count} in {list}.",
        dropped: "Dropped {item} at position {position} of {count} in {list}.",
        cancelled: "Cancelled. {item} is back at position {position} of {count} in {list}."
      }.freeze

      def self.announcements
        ANNOUNCEMENTS.to_h do |key, default|
          [ key, I18n.t("unmagic.components.sortable.#{key}", default: default) ]
        end
      end

      # The <unmagic-sortable-list> and the items recorded into it.
      class List
        def initialize(view, namespace: nil, params: {}, url: nil, orientation: :vertical, label: nil, **options)
          unless ORIENTATIONS.include?(orientation)
            raise ArgumentError, "unknown sortable_list orientation #{orientation.inspect} (expected one of #{ORIENTATIONS.inspect})"
          end

          @view = view
          @namespace = namespace
          @params = params
          @url = url.nil? ? Components.configuration.sortable_url.call(view) : url
          @orientation = orientation
          @label = label
          @options = options
          @items = []
        end

        # An item for a record (its key and rank come from config.sortable_item), or
        # for key: and rank: given directly. label: is what a screen reader hears it
        # called; without it, its text.
        def item(record = nil, key: nil, rank: nil, label: nil, tag: "unmagic-sortable-item", **options, &block)
          attributes = record ? Components.configuration.sortable_item.call(view, record) : {}
          key ||= attributes[:key]
          rank ||= attributes[:rank]
          raise ArgumentError, "a sortable item needs a record or a key:" if key.blank?

          rank = rank.to_s("F") if rank.is_a?(BigDecimal)
          @items << view.content_tag(tag, block ? view.capture(&block) : nil, **options,
            key: key,
            "data-sortable-rank": rank,
            "data-sortable-label": label,
            class: view.class_names("UnmagicSortableItem", options[:class]))
          nil
        end

        def render(extra = nil)
          announcements = Sortable.announcements

          view.content_tag("unmagic-sortable-list", **@options,
            namespace: @namespace.presence,
            url: @url.presence,
            orientation: (@orientation unless @orientation == :vertical),
            label: @label,
            data: announcements.transform_keys { |key| "sortable_#{key}" }.merge(@options[:data] || {}),
            class: view.class_names("UnmagicSortableList", "UnmagicSortableList--#{@orientation}", @options[:class])) do
            view.safe_join [
              *@params.map { |name, value| view.content_tag("unmagic-sortable-param", "", name: name, value: value) },
              *@items,
              extra
            ].compact
          end
        end

        private

        attr_reader :view
      end

      # The grip an item is dragged by. With one in an item, only the grip starts a
      # drag, so the rest of the item stays clickable, and it is the item's keyboard
      # stop.
      def self.handle(view, label: nil, **options)
        label ||= I18n.t("unmagic.components.sortable.handle", default: "Drag to reorder")

        view.tag.button(type: "button", **options,
          "aria-label": label, title: label,
          "data-sortable-handle": "",
          class: view.class_names(Button.classes(:icon), "UnmagicSortableHandle", options[:class])) do
          Icons.svg(view, :grip_vertical)
        end
      end
    end
  end
end
