# frozen_string_literal: true

module Unmagic
  module Components
    # A bordered surface with an optional titled header, a body, and a footer of
    # actions. See ActionViewHelpers#card.
    class Card
      def initialize(view, title: nil, href: nil, flush: false, border: true, background: true, skeleton: false,
        tag_name: :section, **options)
        @view = view
        @title = title
        @href = href
        @flush = flush
        @border = border
        @background = background
        @skeleton = skeleton
        @tag_name = tag_name
        @options = options
        @actions = nil
        @header = nil
        @footer = nil
      end

      # A bar of your own across the top, in place of the title and its actions:
      # a row of tabs, a search field, a run of badges. Options go on the <header>.
      def header(content = nil, **options, &block)
        @header = [ block ? view.capture(&block) : content, options ]
        nil
      end

      # Controls beside the title, on the right of the header.
      def actions(content = nil, &block)
        @actions = block ? view.capture(&block) : content
        nil
      end

      # A tinted row along the bottom.
      def footer(content = nil, &block)
        @footer = block ? view.capture(&block) : content
        nil
      end

      # As a skeleton the card keeps its title and chrome, and a body with nothing in
      # it becomes three lines of text; pass a block to block the body out yourself.
      # The loading label sits on the card itself rather than on a wrapper, so a
      # skeleton card still stretches to its row in a grid.
      def render(body)
        if @header && (@title.present? || @actions.present?)
          raise ArgumentError, "card takes a title and actions, or a header of its own, not both"
        end

        classes = view.class_names("UnmagicCard", {
          "UnmagicCard--link" => @href, "UnmagicCard--borderless" => !@border, "UnmagicCard--transparent" => !@background
        }, @options[:class])
        body = Skeleton.new(view).text(lines: 3) if @skeleton && body.blank?

        view.content_tag(@href ? :a : @tag_name, **@options, href: @href, role: ("status" if @skeleton), class: classes) do
          safe_join [
            (Skeleton.hidden_label(view) if @skeleton),
            header_markup,
            tag.div(body, class: view.class_names("UnmagicCard__body", { "UnmagicCard__body--flush" => @flush })),
            (tag.div(@footer, class: "UnmagicCard__footer") if @footer.present?)
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def header_markup
        if @header
          content, options = @header
          return tag.header(content, **options, class: view.class_names("UnmagicCard__bar", options[:class]))
        end

        return if @title.blank? && @actions.blank?

        tag.header class: "UnmagicCard__header" do
          safe_join [
            (tag.h2(@title, class: "UnmagicCard__title") if @title.present?),
            (tag.div(@actions, class: "UnmagicCard__actions") if @actions.present?)
          ].compact
        end
      end
    end
  end
end
