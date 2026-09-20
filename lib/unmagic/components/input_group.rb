# frozen_string_literal: true

module Unmagic
  module Components
    # A control with something joined to either end of it: a unit, a scheme, a
    # button. See ActionViewHelpers#input_group.
    class InputGroup
      def initialize(view, prefix: nil, suffix: nil, **options)
        @view = view
        @prefix = prefix
        @suffix = suffix
        @options = options
      end

      # Text becomes a tinted addon; markup (a button, an icon) is set in as it is.
      def render(control)
        tag.div(**@options, class: view.class_names("UnmagicInputGroup", @options[:class])) do
          safe_join [ addon(@prefix), control, addon(@suffix) ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def addon(part)
        return if part.blank?
        return tag.span(part, class: "UnmagicInputGroup__addon UnmagicInputGroup__addon--text") unless part.html_safe?

        tag.span(part, class: "UnmagicInputGroup__addon")
      end
    end
  end
end
