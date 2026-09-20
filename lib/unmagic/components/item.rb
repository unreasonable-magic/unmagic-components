# frozen_string_literal: true

module Unmagic
  module Components
    # A row about one thing: its picture, its name over a line about it, and
    # whatever the list wants beside it. See ActionViewHelpers#item.
    class Item
      def initialize(view, title: nil, description: nil, href: nil, mono: false, **options)
        @view = view
        @title = title
        @description = description
        @href = href
        @mono = mono
        @options = options
        @media = nil
        @actions = nil
        @meta = nil
      end

      # Title markup richer than a string. Overrides title:.
      def title(content = nil, &block)
        @title = block ? view.capture(&block) : content
        nil
      end

      def description(content = nil, &block)
        @description = block ? view.capture(&block) : content
        nil
      end

      # The picture on the left: an image, an icon in a box, an avatar.
      def media(content = nil, &block)
        @media = block ? view.capture(&block) : content
        nil
      end

      # Flags beside the title: a badge, a state.
      def meta(content = nil, &block)
        @meta = block ? view.capture(&block) : content
        nil
      end

      # Whatever the list wants on the right: a menu, a button, a reading.
      def actions(content = nil, &block)
        @actions = block ? view.capture(&block) : content
        nil
      end

      # With href: the title is the link, and the whole row is its hit area
      # through a stretched pseudo-element, so the actions can still be links
      # and buttons of their own.
      def render(body)
        classes = view.class_names("UnmagicItem", { "UnmagicItem--link" => @href, "UnmagicItem--mono" => @mono }, @options[:class])

        tag.div(**@options, class: classes) do
          safe_join [
            (tag.div(@media, class: "UnmagicItem__media") if @media.present?),
            tag.div(class: "UnmagicItem__main") do
              safe_join [
                tag.div(class: "UnmagicItem__heading") do
                  safe_join [ title_tag, @meta ].compact
                end,
                (tag.div(@description, class: "UnmagicItem__description") if @description.present?),
                body.presence
              ].compact
            end,
            (tag.div(@actions, class: "UnmagicItem__actions") if @actions.present?)
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def title_tag
        return if @title.blank?

        if @href
          view.link_to(@title, @href, class: "UnmagicItem__title")
        else
          tag.span(@title, class: "UnmagicItem__title")
        end
      end
    end
  end
end
