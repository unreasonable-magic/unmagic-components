# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # One reach for a tool, from the ask through to the answer, as a row in a
      # timeline. See ActionViewHelpers#ai_chat_tool_call.
      class ToolCall
        STATES = %i[queued running waiting done failed].freeze

        LABELS = { queued: "Queued", running: "Running", waiting: "Waiting on you", done: "Done",
                   failed: "Failed" }.freeze

        def initialize(view, name:, state:, id: nil, icon: nil, open: false, timeline: true, **options)
          AIChat.validate!("ai_chat_tool_call", :state, state, STATES)

          @view = view
          @name = name
          @state = state
          @id = id
          @icon = icon
          @open = open
          @timeline = timeline
          @options = options
          @summary = nil
          @timing = nil
          @failures = nil
          @progress = nil
          @payloads = []
          @made = nil
        end

        # What the call was actually about, beside the name: three identical labels
        # say nothing, "search_messages · car seat" does.
        def summary(text)
          @summary = text
          nil
        end

        # A live clock while running, what it took once done, nothing if neither is
        # known — a zero would be a reading, and there isn't one.
        def timing(started_at: nil, duration: nil)
          @timing = { started_at: started_at, duration: duration }
          nil
        end

        def asked(payload, **options)
          @payloads << Payload.new(view, payload, label: AIChat.t("tool_call.asked", default: "Asked"), **options)
          nil
        end

        def answered(payload, **options)
          @payloads << Payload.new(view, payload, label: AIChat.t("tool_call.answered", default: "Answered"), **options)
          nil
        end

        # How much of a batch didn't work, for a call that otherwise did. Nothing for
        # zero, and nothing for a call that failed outright, which already says so.
        def failures(count)
          @failures = count
          nil
        end

        # What the tool is saying while it works. Rendered with its own id so the host
        # can replace just this line as reports come in.
        def progress(text)
          @progress = text
          nil
        end

        # What the call produced. It stays outside the fold: it is the reason the
        # call happened, and hiding it behind a chevron is the wrong way round.
        def made(content = nil, &block)
          @made = block ? view.capture(&block) : content
          nil
        end

        # Supply facts and translated content; the element owns state presentation.
        def render
          payloads = @payloads.map(&:render).select(&:present?)
          labels = LABELS.to_h { |state, fallback| [ "label-#{state}", AIChat.t("tool_call.#{state}", default: fallback) ] }
          view.content_tag("unmagic-tool-call", **@options, **labels, id: @id, open: @open, state: @state,
            "aria-busy": ("true" if @state == :running),
            data: { ai_chat_timeline: ("row" if @timeline) }.merge(@options[:data] || {}),
            class: view.class_names("UnmagicAIChatToolCall", "UnmagicAIChatToolCall--#{@state}", @options[:class])) do
            safe_join [
              tag.span(safe_join([
                tag.span(labels.fetch("label-#{@state}"), "data-part": "status"),
                tag.code(@name, "data-part": "name", class: "UnmagicAIChatToolCall__name"),
                (tag.span(@summary, "data-part": "summary", class: "UnmagicAIChatToolCall__summary") if @summary.present?),
                readings,
                (tag.span(@progress, "data-part": "progress", id: ("#{@id}_progress" if @id),
                  class: "UnmagicAIChatToolCall__progress") if @progress.present?)
              ].compact), "data-part": "row", class: "UnmagicAIChatToolCall__row"),
              (tag.template(Icons.svg(view, @icon), "data-part": "success-icon") if @icon),
              *payloads.map { |payload| tag.div(payload, "data-part": "payload") },
              (tag.div(@made, "data-part": "result", class: "UnmagicAIChatToolCall__made") if @made.present?)
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def readings
          parts = []
          unless @failures.to_i.zero?
            parts << tag.span(reading(:triangle_alert, AIChat.t("tool_call.partly_failed", default: "Partly failed"),
              AIChat.t("tool_call.failures", count: @failures, default: "%{count} failed"), modifier: "warn"), "data-part": "failures")
          end
          if @timing&.dig(:started_at)
            parts << tag.span(reading(:timer, AIChat.t("tool_call.running_for", default: "Running for"),
              Elapsed.new(view, @timing[:started_at], direction: :up).render), "data-part": "elapsed")
          end
          if @timing&.dig(:duration)
            parts << tag.span(reading(:timer, AIChat.t("tool_call.took", default: "Took"),
              Duration.format(@timing[:duration])), "data-part": "duration")
          end
          tag.span(safe_join(parts), "data-part": "readings", class: "UnmagicAIChatToolCall__readings") if parts.any?
        end

        # Each reading leads with a glyph, so a run of small grey numbers can be told
        # apart before the digits are read.
        def reading(icon, label, value, modifier: nil)
          tag.span(class: view.class_names("UnmagicAIChatToolCall__reading",
            "UnmagicAIChatToolCall__reading--#{modifier}" => modifier)) do
            safe_join [ Icons.svg(view, icon), tag.span(label, class: "UnmagicVisuallyHidden"), value ]
          end
        end
      end
    end
  end
end
