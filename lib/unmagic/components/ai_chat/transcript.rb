# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The scrolling region a conversation's turns are rendered into, and the
      # spacing between them. It renders no entries of its own: the host keeps a
      # partial per entry type. See ActionViewHelpers#ai_chat.
      class Transcript
        def initialize(view, id:, scroller: nil, follow: true, scroll_to_latest: true, **options)
          raise ArgumentError, "ai_chat needs an id: for entries to be broadcast into" if id.blank?

          @view = view
          @id = id
          @scroller = scroller
          @follow = follow
          @scroll_to_latest = scroll_to_latest
          @options = options
          @welcome = nil
        end

        # Shown while the conversation is empty. It renders inside the log, so the
        # first entry streamed in hides it (see the CSS) without another request.
        def welcome(content = nil, &block)
          @welcome = block ? view.capture(&block) : content
          nil
        end

        # Always renders the log, empty or not: a broadcast can only land in an
        # element that is already on the page.
        def render(entries)
          log = view.content_tag(:div, **@options,
            id: @id,
            role: "log",
            "aria-live": "polite",
            "aria-relevant": "additions",
            "aria-label": AIChat.t("transcript.label", default: "Conversation"),
            class: view.class_names("UnmagicAIChat", @options[:class])) do
            safe_join [ (tag.div(@welcome, class: "UnmagicAIChat__welcome") if @welcome && entries.blank?), entries ].compact
          end

          return log unless @follow

          view.content_tag("unmagic-autoscroll", scroller: @scroller, class: "UnmagicAutoscroll") do
            safe_join [ log, (latest if @scroll_to_latest) ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # A real button in the tab order, shown by <unmagic-autoscroll> only while
        # the reader has scrolled away from the bottom.
        def latest
          label = AIChat.t("transcript.latest", default: "Jump to latest")

          tag.div(class: "UnmagicAIChat__latest") do
            tag.button(Icons.svg(view, :arrow_down), type: "button", hidden: true, "data-autoscroll-latest": "",
              "aria-label": label, title: label, class: "UnmagicAIChat__latestButton")
          end
        end
      end
    end
  end
end
