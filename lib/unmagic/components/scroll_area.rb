# frozen_string_literal: true

module Unmagic
  module Components
    # A box that scrolls, with shadows where there is more to see. See
    # ActionViewHelpers#scroll_area.
    class ScrollArea
      AXES = %i[y x both].freeze

      def initialize(view, axis: :y, max_height: nil, label: nil, shadows: true, **options)
        raise ArgumentError, "unknown scroll_area axis #{axis.inspect} (expected one of #{AXES.inspect})" unless AXES.include?(axis)

        @view = view
        @axis = axis
        @max_height = max_height
        @label = label
        @shadows = shadows
        @options = options
      end

      # With a label it is a named region a keyboard can reach and scroll;
      # without one, only its own links and buttons are.
      def render(body)
        classes = view.class_names("UnmagicScrollArea", "UnmagicScrollArea--#{@axis}", { "UnmagicScrollArea--shadows" => @shadows }, @options[:class])
        style = [ @options[:style], ("--unmagic-scroll-area-max-height: #{@max_height}" if @max_height) ].compact.join("; ").presence
        region = @label ? { role: "region", "aria-label": @label, tabindex: 0 } : {}

        tag.div(body, **@options, **region, class: classes, style: style)
      end

      private

      attr_reader :view

      delegate :tag, to: :view, private: true
    end
  end
end
