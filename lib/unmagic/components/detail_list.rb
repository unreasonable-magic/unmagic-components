# frozen_string_literal: true

module Unmagic
  module Components
    # Collects the items a `detail_list` block declares and renders them as a
    # <dl>. See ActionViewHelpers#detail_list for the public API.
    class DetailList
      VARIANTS = %i[inline stacked].freeze

      # Values vary in length, so a skeleton's bars do too.
      SKELETON_WIDTHS = %w[55% 40% 70% 35% 60%].freeze

      def initialize(view, variant:, skeleton: false, **options)
        unless VARIANTS.include?(variant)
          raise ArgumentError, "unknown detail_list variant #{variant.inspect} (expected one of #{VARIANTS.inspect})"
        end

        @view = view
        @variant = variant
        @skeleton = skeleton
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

        list = tag.dl class: classes do
          safe_join @items.map { |item| stacked? ? stacked_item(item) : inline_item(item) }
        end

        # A <dl> may only hold its items, so the loading label goes around it.
        @skeleton ? Skeleton.group(view) { list } : list
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

      # A skeleton keeps the real labels and stands a bar in for each value.
      def value(item)
        if @skeleton
          Skeleton.new(view).text(width: SKELETON_WIDTHS[@items.index(item) % SKELETON_WIDTHS.size])
        elsif item.block
          view.capture(&item.block).presence || "—"
        else
          item.value
        end
      end
    end
  end
end
