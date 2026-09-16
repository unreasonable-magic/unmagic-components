# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The model's thinking, collapsed above the reply it led to. See
      # ActionViewHelpers#ai_chat_reasoning.
      class Reasoning
        def initialize(view, title: nil, streaming: false, duration: nil, open: false, id: nil, **options)
          @view = view
          @title = title
          @streaming = streaming
          @duration = duration
          @open = open
          @id = id
          @options = options
          @blocks = []
        end

        def block(content = nil, &block)
          @blocks << (block ? view.capture(&block) : content)
          nil
        end

        # Nothing at all when there is no reasoning, unless it is still arriving: a
        # turn that didn't think should leave no chrome behind.
        def render(content = nil)
          blocks = [ content, *@blocks ].select(&:present?)
          return "".html_safe if blocks.empty? && !@streaming

          tag.details(**@options, open: @open, class: view.class_names("UnmagicAIChatReasoning", @options[:class])) do
            safe_join [ summary, *blocks.each_with_index.map { |markup, index| body(markup, index) } ]
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def summary
          tag.summary(class: "UnmagicAIChatReasoning__head", "aria-busy": ("true" if @streaming)) do
            safe_join [
              (Icons.svg(view, :loader_circle, class: "UnmagicAIChatSpinner") if @streaming),
              tag.span(title, class: "UnmagicAIChatReasoning__title"),
              Icons.svg(view, :chevron_right, class: "UnmagicAIChatChevron")
            ].compact
          end
        end

        def title
          if @streaming
            AIChat.t("reasoning.thinking", default: "Thinking…")
          elsif @duration
            AIChat.t("reasoning.duration", duration: Duration.format(@duration), default: "Thought for %{duration}")
          else
            @title || AIChat.t("reasoning.title", default: "Thought process")
          end
        end

        # A block that is still arriving reveals at the reply's pace, so it needs
        # an id to stream into; the first block takes the caller's.
        def body(markup, index)
          classes = "UnmagicAIChatReasoning__block UnmagicProse"
          if @streaming && @id
            StreamingMarkdown.new(view, id: index.zero? ? @id : "#{@id}_#{index}", streaming: true, class: classes).render(markup)
          else
            tag.div(markup, class: classes)
          end
        end
      end
    end
  end
end
