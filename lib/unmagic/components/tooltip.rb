# frozen_string_literal: true

module Unmagic
  module Components
    # A hint shown on hover or focus. See ActionViewHelpers#tooltip.
    class Tooltip
      PLACEMENTS = %i[top bottom].freeze

      def initialize(view, text:, placement:, term:, **options)
        unless PLACEMENTS.include?(placement)
          raise ArgumentError, "unknown tooltip placement #{placement.inspect} (expected one of #{PLACEMENTS.inspect})"
        end

        @view = view
        @text = text
        @placement = placement
        @term = term
        @options = options
      end

      def render(content)
        classes = view.class_names("UnmagicTooltip", { "UnmagicTooltip--term" => @term }, @options[:class])

        view.content_tag("unmagic-tooltip", content, **@options, text: @text, placement: @placement, class: classes)
      end

      private

      attr_reader :view
    end
  end
end
