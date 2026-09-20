# frozen_string_literal: true

module Unmagic
  module Components
    # A rule between two things, with a word on it or not. See ActionViewHelpers#separator.
    class Separator
      ORIENTATIONS = %i[horizontal vertical].freeze

      def initialize(view, label = nil, orientation: :horizontal, **options)
        unless ORIENTATIONS.include?(orientation)
          raise ArgumentError, "unknown separator orientation #{orientation.inspect} (expected one of #{ORIENTATIONS.inspect})"
        end

        @view = view
        @label = label
        @orientation = orientation
        @options = options
      end

      # A plain horizontal rule is an <hr>, which is what it is. One with a word on
      # it, or a vertical one, is a div that says so.
      def render
        classes = view.class_names("UnmagicSeparator", { "UnmagicSeparator--vertical" => @orientation == :vertical },
          @options[:class])

        if @label.blank? && @orientation == :horizontal
          tag.hr(**@options, class: classes)
        else
          tag.div(**@options, role: "separator", "aria-orientation": (@orientation if @orientation == :vertical),
            class: classes) do
            tag.span(@label, class: "UnmagicSeparator__label") if @label.present?
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, to: :view, private: true
    end
  end
end
