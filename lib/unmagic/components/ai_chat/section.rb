# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The collapsible panel section a plan and a workspace share: a glyph, a
      # title, a count and a chevron over a body. Always rendered, empty or not,
      # because both are broadcast targets.
      class Section
        def initialize(view, block:, icon:, title:, count:, open:, collapsible:, title_tag:, options:)
          @view = view
          @block = block
          @icon = icon
          @title = title
          @count = count
          @open = open
          @collapsible = collapsible
          @title_tag = title_tag
          @options = options
        end

        def render(body)
          classes = view.class_names(@block, { "#{@block}--static" => !@collapsible }, @options[:class])

          if @collapsible
            tag.details(**@options, open: @open, class: classes) do
              safe_join [ tag.summary(head(chevron: true), class: "#{@block}__head"), body ]
            end
          else
            tag.section(**@options, class: classes) do
              safe_join [ tag.div(head(chevron: false), class: "#{@block}__head"), body ]
            end
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def head(chevron:)
          safe_join [
            Icons.svg(view, @icon, class: "#{@block}__icon"),
            view.content_tag(@title_tag, @title, class: "#{@block}__title"),
            (Icons.svg(view, :chevron_right, class: "UnmagicAIChatChevron") if chevron),
            (tag.span(@count, class: "#{@block}__count") if @count.present?)
          ].compact
        end
      end
    end
  end
end
