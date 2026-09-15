# frozen_string_literal: true

module Unmagic
  module Components
    # A timestamp the browser rewrites in the viewer's own locale and time zone.
    # The server renders a readable fallback, in Time.zone, for the moment before
    # the element upgrades. See ActionViewHelpers#local_time_tag.
    class LocalTime
      FORMATS = %i[short medium long full date time relative].freeze

      # The server fallback for each absolute format, in I18n's time formats.
      I18N_FORMATS = { short: :short, medium: :default, long: :long, full: :long }.freeze

      def initialize(view, time, format:, compact:, **options)
        unless FORMATS.include?(format)
          raise ArgumentError, "unknown local_time_tag format #{format.inspect} (expected one of #{FORMATS.inspect})"
        end

        @view = view
        @time = time.in_time_zone
        @format = format
        @compact = compact
        @options = options
      end

      # The attributes live on the element, where a morph that changes them is
      # seen; the inner <time> keeps the markup meaningful without the script.
      def render
        datetime = @time.utc.iso8601

        view.content_tag("unmagic-time", datetime: datetime, format: @format, compact: ("" if @compact), **@options) do
          tag.time(fallback, datetime: datetime, title: (I18n.l(@time, format: :long) if relative?))
        end
      end

      private

      attr_reader :view

      delegate :tag, to: :view, private: true

      def relative? = @format == :relative

      def fallback
        case @format
        when :relative then relative_phrase
        when :date then I18n.l(@time.to_date, format: :long)
        when :time then I18n.l(@time, format: "%H:%M")
        else I18n.l(@time, format: I18N_FORMATS.fetch(@format))
        end
      end

      def relative_phrase
        distance = view.distance_of_time_in_words(Time.current, @time)

        if @time.past?
          I18n.t("unmagic.components.time.past", distance: distance, default: "%{distance} ago")
        else
          I18n.t("unmagic.components.time.future", distance: distance, default: "in %{distance}")
        end
      end
    end
  end
end
