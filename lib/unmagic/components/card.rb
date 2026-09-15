# frozen_string_literal: true

module Unmagic
  module Components
    # A bordered surface with an optional titled header, a body, and a footer of
    # actions. See ActionViewHelpers#card.
    class Card
      def initialize(view, title: nil, href: nil, flush: false, skeleton: false, **options)
        @view = view
        @title = title
        @href = href
        @flush = flush
        @skeleton = skeleton
        @options = options
        @actions = nil
        @footer = nil
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
        classes = view.class_names("UnmagicCard", { "UnmagicCard--link" => @href }, @options[:class])
        body = Skeleton.new(view).text(lines: 3) if @skeleton && body.blank?

        view.content_tag(@href ? :a : :section, **@options, href: @href, role: ("status" if @skeleton), class: classes) do
          safe_join [
            (Skeleton.hidden_label(view) if @skeleton),
            header,
            tag.div(body, class: view.class_names("UnmagicCard__body", { "UnmagicCard__body--flush" => @flush })),
            (tag.div(@footer, class: "UnmagicCard__footer") if @footer.present?)
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def header
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
