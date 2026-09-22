# frozen_string_literal: true

module Unmagic
  module Components
    # Things that happened, in order, joined by a line. See ActionViewHelpers#timeline.
    class Timeline
      ORIENTATIONS = %i[vertical horizontal].freeze
      TONES = %i[neutral good warn bad info].freeze

      # CSS's list-style-type names, for what an event with no icon or avatar shows.
      MARKERS = %i[dot decimal lower_alpha upper_alpha lower_roman upper_roman].freeze
      ROMAN = { 1000 => "m", 900 => "cm", 500 => "d", 400 => "cd", 100 => "c", 90 => "xc", 50 => "l", 40 => "xl",
                10 => "x", 9 => "ix", 5 => "v", 4 => "iv", 1 => "i" }.freeze

      # A skeleton's titles vary in length, so the placeholder doesn't read as a grid.
      SKELETON_WIDTHS = %w[55% 40% 65%].freeze

      def initialize(view, orientation: :vertical, label: nil, marker: :dot, skeleton: false, **options)
        unless ORIENTATIONS.include?(orientation)
          raise ArgumentError, "unknown timeline orientation #{orientation.inspect} (expected one of #{ORIENTATIONS.inspect})"
        end
        unless MARKERS.include?(marker)
          raise ArgumentError, "unknown timeline marker #{marker.inspect} (expected one of #{MARKERS.inspect})"
        end

        @view = view
        @orientation = orientation
        @label = label
        @marker = marker
        @skeleton = skeleton
        @options = options
        @events = []
      end

      # One thing that happened. The block, if any, is its body.
      def event(title, time: nil, time_format: nil, icon: nil, avatar: nil, tone: :neutral, pending: false,
                href: nil, description: nil, **options, &block)
        raise ArgumentError, "a timeline event needs a title" if title.blank?
        raise ArgumentError, "a timeline event takes icon: or avatar:, not both" if icon && avatar
        unless TONES.include?(tone)
          raise ArgumentError, "unknown timeline tone #{tone.inspect} (expected one of #{TONES.inspect})"
        end

        body = view.capture(&block) if block
        @events << tag.li(**options, "data-tone": tone, "data-pending": ("" if pending),
          class: view.class_names("UnmagicTimeline__event", options[:class])) do
          safe_join [
            marker(icon: icon, avatar: avatar, position: @events.size + 1),
            tag.div(class: "UnmagicTimeline__content") do
              safe_join [
                header(title, href: href, time: time, time_format: time_format, pending: pending),
                (tag.p(description, class: "UnmagicTimeline__description") if description.present?),
                (tag.div(body, class: "UnmagicTimeline__body") if body.present?)
              ].compact
            end
          ]
        end
        nil
      end

      def render
        return skeleton if @skeleton
        return if @events.empty?

        list(@events)
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def list(events)
        tag.ol(safe_join(events), **@options, "aria-label": @options.fetch(:"aria-label", @label),
          class: view.class_names("UnmagicTimeline", "UnmagicTimeline--#{@orientation}", @options[:class]))
      end

      def marker(icon:, avatar:, position:)
        if avatar
          name, options = avatar.is_a?(Hash) ? [ avatar[:name], avatar.except(:name) ] : [ avatar, {} ]
          content = Avatar.new(view, name, **options, size: :small).render
          kind = "avatar"
        elsif icon
          content = Icons.svg(view, icon)
          kind = "icon"
        elsif @marker != :dot
          # The list already says "2 of 3" to a screen reader; this is for eyes.
          content = counter(position)
          kind = "counter"
        else
          kind = "dot"
        end

        tag.span(content, class: "UnmagicTimeline__marker UnmagicTimeline__marker--#{kind}", "aria-hidden": "true")
      end

      # The event's position in the timeline's marker style: 3, c, C, iii or III.
      def counter(position)
        case @marker
        when :decimal then position.to_s
        when :lower_alpha, :upper_alpha then alpha(position)
        else roman(position)
        end.then { |text| @marker.start_with?("upper") ? text.upcase : text }
      end

      def roman(position)
        ROMAN.each_with_object(+"") do |(value, letters), roman|
          count, position = position.divmod(value)
          roman << letters * count
        end
      end

      # a…z, then aa, ab, as CSS counts.
      def alpha(position)
        letters = +""
        while position.positive?
          position, remainder = (position - 1).divmod(26)
          letters.prepend((97 + remainder).chr)
        end
        letters
      end

      def header(title, href:, time:, time_format:, pending:)
        tag.div(class: "UnmagicTimeline__header") do
          safe_join [
            href ? view.link_to(title, href, class: "UnmagicTimeline__title") : tag.span(title, class: "UnmagicTimeline__title"),
            time_tag(time, time_format),
            (tag.span(I18n.t("unmagic.components.timeline.pending", default: "(upcoming)"), class: "UnmagicVisuallyHidden") if pending)
          ].compact
        end
      end

      # A moment goes through local_time_tag, so it reads in the viewer's zone; a
      # string ("Q4", "v2.0") is a label and prints as it is.
      def time_tag(time, format)
        case time
        when nil, "" then nil
        when String then tag.span(time, class: "UnmagicTimeline__time")
        else
          format ||= time.is_a?(Date) && !time.is_a?(DateTime) ? :date : :medium
          LocalTime.new(view, time, format: format, compact: false, class: "UnmagicTimeline__time").render
        end
      end

      def skeleton
        shapes = Skeleton.new(view)
        events = SKELETON_WIDTHS.map do |width|
          tag.li(class: "UnmagicTimeline__event") do
            safe_join [
              tag.span(class: "UnmagicTimeline__marker UnmagicTimeline__marker--dot", "aria-hidden": "true"),
              tag.div(class: "UnmagicTimeline__content") do
                safe_join [
                  shapes.text(width: width),
                  tag.p(shapes.text(width: "30%"), class: "UnmagicTimeline__description")
                ]
              end
            ]
          end
        end

        Skeleton.group(view) { list(events) }
      end
    end
  end
end
