# frozen_string_literal: true

module Unmagic
  module Components
    # A titled run of a page: a small heading with what qualifies it beside it
    # and the button that acts on it hard right, then the run itself. See
    # ActionViewHelpers#section.
    class Section
      SPACINGS = %i[normal tight none].freeze

      def initialize(view, title, spacing: :normal, heading: :h2, **options)
        unless SPACINGS.include?(spacing)
          raise ArgumentError, "unknown section spacing #{spacing.inspect} (expected one of #{SPACINGS.inspect})"
        end

        @view = view
        @title = title
        @spacing = spacing
        @heading = heading
        @options = options
        @aside = nil
        @actions = nil
      end

      # What qualifies the title: a count, a state badge. Sits right beside it.
      def aside(content = nil, &block)
        @aside = block ? view.capture(&block) : content
        nil
      end

      # The button that acts on the whole run, hard right.
      def actions(content = nil, &block)
        @actions = block ? view.capture(&block) : content
        nil
      end

      def render(body)
        classes = view.class_names("UnmagicSection", "UnmagicSection--#{@spacing}", @options[:class])

        tag.section(**@options, class: classes) do
          safe_join [
            tag.div(class: "UnmagicSection__head") do
              safe_join [
                tag.div(class: "UnmagicSection__heading") do
                  safe_join [ view.content_tag(@heading, @title, class: "UnmagicSection__title"), @aside ].compact
                end,
                (tag.div(@actions, class: "UnmagicSection__actions") if @actions.present?)
              ].compact
            end,
            body
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
