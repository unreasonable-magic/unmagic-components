# frozen_string_literal: true

module Unmagic
  module Components
    # Collects the items a `detail_list` block declares and renders them as a
    # <dl>. See ActionViewHelpers#detail_list for the public API.
    class DetailList
      VARIANTS = %i[inline stacked].freeze

      def initialize(view, variant:, **options)
        unless VARIANTS.include?(variant)
          raise ArgumentError, "unknown detail_list variant #{variant.inspect} (expected one of #{VARIANTS.inspect})"
        end

        @view = view
        @variant = variant
        @classes = options[:class]
        @items = []
      end

      def item(label, value = nil, **options, &block)
        @items << Item.new(label: label, value: value, block: block, **options)
        nil
      end

      def render
        classes = view.class_names(
          "UnmagicDescriptionList",
          { "UnmagicDescriptionList--stacked" => stacked? },
          @classes,
        )

        tag.dl class: classes do
          safe_join @items.map { |item| stacked? ? stacked_item(item) : inline_item(item) }
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def stacked? = @variant == :stacked

      def inline_item(item)
        safe_join [ tag.dt(item.label), tag.dd(value(item), class: item.dd_classes) ]
      end

      def stacked_item(item)
        tag.div class: ("is-full" if item.full_span?) do
          safe_join [ tag.dt(item.label), tag.dd(value(item), class: item.dd_classes) ]
        end
      end

      def value(item)
        if item.block
          view.capture(&item.block).presence || "—"
        else
          item.value
        end
      end
    end
  end
end
