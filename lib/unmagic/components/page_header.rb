# frozen_string_literal: true

module Unmagic
  module Components
    # The top of a page: an optional back link, the title with badges beside it,
    # a description, and the page's actions on the right. See
    # ActionViewHelpers#page_header.
    class PageHeader
      def initialize(view, title: nil, description: nil, back: nil, skeleton: false, **options)
        @view = view
        @title = title
        @description = description
        @back = back
        @skeleton = skeleton
        @options = options
        @leading = nil
        @badges = []
      end

      # Title markup richer than a string — a <code>, a link. Overrides title:.
      def title(content = nil, &block)
        @title = block ? view.capture(&block) : content
        nil
      end

      # A description with markup in it. Overrides description:.
      def description(content = nil, &block)
        @description = block ? view.capture(&block) : content
        nil
      end

      # Something before the title, such as an avatar.
      def leading(content = nil, &block)
        @leading = block ? view.capture(&block) : content
        nil
      end

      # A badge beside the title. Call it once per badge.
      def badge(content = nil, tone: :neutral, &block)
        @badges << tag.span(block ? view.capture(&block) : content, class: Badge.classes(tone))
        nil
      end

      # As a skeleton, anything given still renders for real, and the rest stands in
      # as shapes: a title bar, a description line (unless description: false) and
      # a button.
      def render(actions)
        actions = Skeleton.new(view).button if @skeleton && actions.blank?

        tag.header(**@options, role: ("status" if @skeleton),
          class: view.class_names("UnmagicPageHeader", @options[:class])) do
          safe_join [
            (Skeleton.hidden_label(view) if @skeleton),
            back_link,
            tag.div(class: "UnmagicPageHeader__row") do
              safe_join [
                tag.div(safe_join([ heading, description_tag ].compact), class: "UnmagicPageHeader__main"),
                (tag.div(actions, class: "UnmagicPageHeader__actions") if actions.present?)
              ].compact
            end
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def back_link
        return unless @back

        text, path = @back.values_at(:text, :path)
        view.link_to path, class: "UnmagicPageHeader__back" do
          safe_join [ Icons.svg(view, :arrow_left), text ]
        end
      end

      def heading
        tag.div class: "UnmagicPageHeader__heading" do
          title = @title.presence || (Skeleton.new(view).text(width: "14rem") if @skeleton)
          safe_join [ @leading, tag.h1(title, class: "UnmagicPageHeader__title"), *@badges ].compact
        end
      end

      def description_tag
        if @description.present?
          tag.div(@description, class: "UnmagicPageHeader__description")
        elsif @skeleton && @description != false
          tag.div(Skeleton.new(view).text(width: "32rem"), class: "UnmagicPageHeader__description")
        end
      end
    end
  end
end
