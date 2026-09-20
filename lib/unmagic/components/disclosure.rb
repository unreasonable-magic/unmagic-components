# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A summary that folds a panel open, and an accordion of them. See
    # ActionViewHelpers#disclosure and #accordion.
    class Disclosure
      def initialize(view, summary = nil, open: false, accordion: nil, **options)
        @view = view
        @summary = summary
        @open = open
        @accordion = accordion
        @options = options
      end

      # Summary markup richer than a string: a badge beside the title.
      def summary(content = nil, &block)
        @summary = block ? view.capture(&block) : content
        nil
      end

      def render(body)
        raise ArgumentError, "disclosure needs a summary" if @summary.blank?

        in_accordion = @accordion.present?
        classes = view.class_names("UnmagicDisclosure", { "UnmagicDisclosure--in-accordion" => in_accordion }, @options[:class])
        chevron = Icons.svg(view, in_accordion ? :chevron_down : :chevron_right, class: "UnmagicDisclosure__chevron")
        title = tag.span(@summary, class: "UnmagicDisclosure__title")

        tag.details(**@options, class: classes, open: @open || nil, name: @accordion) do
          safe_join [
            tag.summary(safe_join(in_accordion ? [ title, chevron ] : [ chevron, title ]), class: "UnmagicDisclosure__summary"),
            tag.div(body, class: "UnmagicDisclosure__panel")
          ]
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end

    # One item open at a time, through the platform's own <details name>.
    class Accordion
      def initialize(view, id: nil, exclusive: false, **options)
        @view = view
        @id = id || "unmagic_accordion_#{SecureRandom.hex(4)}"
        @exclusive = exclusive
        @options = options
        @items = []
        @open = 0
      end

      def item(summary = nil, open: false, **options, &block)
        @open += 1 if open
        raise ArgumentError, "an exclusive accordion can open only one item" if @exclusive && @open > 1

        builder = Disclosure.new(view, summary, open: open, accordion: (@id if @exclusive), **options)
        @items << builder.render(view.capture(builder, &block))
        nil
      end

      def render
        return "".html_safe if @items.empty?

        tag.div(safe_join(@items), **@options, id: @id, class: view.class_names("UnmagicAccordion", @options[:class]))
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
