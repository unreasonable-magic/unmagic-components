# frozen_string_literal: true

module Unmagic
  module Components
    # A clock counting up from a moment the server named, or down to one. See
    # ActionViewHelpers#elapsed_tag.
    class Elapsed
      DIRECTIONS = %i[up down].freeze

      def initialize(view, time, direction:, **options)
        unless DIRECTIONS.include?(direction)
          raise ArgumentError, "unknown elapsed_tag direction #{direction.inspect} (expected one of #{DIRECTIONS.inspect})"
        end

        @view = view
        @time = time.in_time_zone
        @direction = direction
        @options = options
      end

      # The server writes the reading the element would, so it is right before the
      # script loads. Whole seconds, floored going up and ceiled going down: a
      # stopwatch says how long it has been, not how long it nearly has been.
      def render
        attribute = @direction == :up ? :since : :until

        view.content_tag("unmagic-elapsed", Duration.format(seconds), **@options,
          attribute => @time.utc.iso8601(3),
          title: I18n.l(@time, format: :long),
          class: view.class_names("UnmagicElapsed", @options[:class]))
      end

      private

      attr_reader :view

      def seconds
        if @direction == :up
          [ (Time.current - @time).floor, 0 ].max
        else
          [ (@time - Time.current).ceil, 0 ].max
        end
      end
    end
  end
end
