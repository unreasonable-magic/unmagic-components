# frozen_string_literal: true

module Unmagic
  module Components
    # A ring that turns while something loads. See ActionViewHelpers#spinner.
    class Spinner
      SIZES = %i[small medium large].freeze

      def initialize(view, text = nil, label: nil, size: :medium, **options)
        unless SIZES.include?(size)
          raise ArgumentError, "unknown spinner size #{size.inspect} (expected one of #{SIZES.inspect})"
        end

        @view = view
        @text = text
        @label = label.nil? ? I18n.t("unmagic.components.spinner.label", default: "Loading…") : label
        @size = size
        @options = options
      end

      # Visible text is the label. Otherwise the label is read but not seen, and
      # label: false makes the ring decorative, for a control that already says
      # what is happening.
      def render
        decorative = @text.blank? && @label == false
        classes = view.class_names("UnmagicSpinner", "UnmagicSpinner--#{@size}", @options[:class])

        tag.span(**@options, class: classes, role: ("status" unless decorative), "aria-hidden": ("true" if decorative)) do
          safe_join [
            Icons.svg(view, :loader_circle, class: "UnmagicSpinner__ring"),
            (@text.present? ? tag.span(@text, class: "UnmagicSpinner__text") : nil),
            (@text.blank? && !decorative ? tag.span(@label, class: "UnmagicVisuallyHidden") : nil)
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
