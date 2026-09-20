# frozen_string_literal: true

module Unmagic
  module Components
    # A bar filled to a fraction of the way. See ActionViewHelpers#progress.
    class Progress
      TONES = %i[neutral good warn bad info].freeze
      SIZES = %i[small medium large].freeze

      def initialize(view, value = nil, max: 100, tone: :neutral, size: :medium, label: nil, indeterminate: false,
        **options)
        unless TONES.include?(tone)
          raise ArgumentError, "unknown progress tone #{tone.inspect} (expected one of #{TONES.inspect})"
        end
        unless SIZES.include?(size)
          raise ArgumentError, "unknown progress size #{size.inspect} (expected one of #{SIZES.inspect})"
        end
        raise ArgumentError, "progress max: must be positive" unless max.to_f.positive?

        @view = view
        @value = value
        @max = max
        @tone = tone
        @size = size
        @label = label || I18n.t("unmagic.components.progress.label", default: "Progress")
        @indeterminate = indeterminate || value.nil?
        @options = options
      end

      def render
        classes = view.class_names("UnmagicProgress", "UnmagicProgress--#{@size}", "UnmagicProgress--#{@tone}",
          { "UnmagicProgress--indeterminate" => @indeterminate }, @options[:class])

        tag.div(**@options, role: "progressbar", "aria-label": @label, "aria-valuemin": 0, "aria-valuemax": @max,
          "aria-valuenow": (@indeterminate ? nil : clamped), class: classes) do
          tag.div(class: "UnmagicProgress__bar", style: ("width: #{percent}%" unless @indeterminate))
        end
      end

      private

      attr_reader :view

      delegate :tag, to: :view, private: true

      def clamped = @value.to_f.clamp(0, @max.to_f)

      def percent = (clamped / @max.to_f * 100).round(1).to_s.delete_suffix(".0")
    end
  end
end
