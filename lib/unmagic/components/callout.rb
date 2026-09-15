# frozen_string_literal: true

module Unmagic
  module Components
    # A tinted callout stating the state of something in place: a leading icon
    # beside the message, optionally under a title with a badge. See
    # ActionViewHelpers#callout.
    class Callout
      TONES = %i[neutral good warn bad info].freeze

      def initialize(view, title: nil, tone: :neutral, badge: nil, icon: true, **options)
        unless TONES.include?(tone)
          raise ArgumentError, "unknown callout tone #{tone.inspect} (expected one of #{TONES.inspect})"
        end

        @view = view
        @title = title
        @tone = tone
        @badge = badge
        @icon = icon
        @options = options
      end

      def render(body)
        classes = view.class_names("UnmagicCallout", "UnmagicCallout--#{@tone}", @options[:class])

        tag.div(**@options, class: classes) do
          safe_join [
            icon,
            tag.div(class: "UnmagicCallout__content") do
              safe_join [ heading, tag.div(body, class: "UnmagicCallout__body") ].compact
            end
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def icon
        name = Icons::TONE_ICONS[@tone]
        Icons.svg(view, name, class: "UnmagicCallout__icon") if @icon && name
      end

      def heading
        return if @title.blank? && @badge.blank?

        tag.div class: "UnmagicCallout__heading" do
          safe_join [
            (tag.p(@title, class: "UnmagicCallout__title") if @title.present?),
            (tag.span(@badge, class: Badge.classes(@tone)) if @badge.present?)
          ].compact
        end
      end
    end
  end
end
