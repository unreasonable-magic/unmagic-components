# frozen_string_literal: true

module Unmagic
  module Components
    # Buttons joined edge to edge into one control. See ActionViewHelpers#button_group.
    class ButtonGroup
      ORIENTATIONS = %i[horizontal vertical].freeze

      def initialize(view, label: nil, orientation: :horizontal, **options)
        unless ORIENTATIONS.include?(orientation)
          raise ArgumentError, "unknown button_group orientation #{orientation.inspect} (expected one of #{ORIENTATIONS.inspect})"
        end

        @view = view
        @label = label
        @orientation = orientation
        @options = options
        @items = []
      end

      # The same arguments as the button helper.
      def button(label = nil, variant = :default, **options, &block)
        @items << ButtonTag.new(view, block ? view.capture(&block) : label, variant: variant, **options).render
        nil
      end

      # Anything else that should sit in the run: a menu, a select.
      def item(content = nil, &block)
        @items << (block ? view.capture(&block) : content)
        nil
      end

      def render
        return "".html_safe if @items.empty?

        classes = view.class_names("UnmagicButtonGroup", { "UnmagicButtonGroup--vertical" => @orientation == :vertical },
          @options[:class])

        tag.div(safe_join(@items), **@options, role: "group", "aria-label": @label, class: classes)
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
