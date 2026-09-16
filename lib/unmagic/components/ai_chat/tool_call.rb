# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # One reach for a tool, from the ask through to the answer, as a row in a
      # timeline. See ActionViewHelpers#ai_chat_tool_call.
      class ToolCall
        STATES = %i[queued running waiting done failed].freeze

        GLYPHS = { queued: :circle_dashed, running: :loader_circle, waiting: :circle_question_mark,
                   done: :circle_check, failed: :circle_x }.freeze

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

        def render
          payloads = @payloads.map(&:render).select(&:present?)

          view.content_tag(:div, **@options,
            id: @id,
            "aria-busy": ("true" if @state == :running),
            data: { ai_chat_timeline: ("row" if @timeline) }.merge(@options[:data] || {}),
            class: view.class_names("UnmagicAIChatToolCall", "UnmagicAIChatToolCall--#{@state}", @options[:class])) do
            safe_join [
              (tag.span(class: "UnmagicAIChatToolCall__join", "aria-hidden": "true") if @timeline),
              payloads.any? ? disclosure(payloads) : tag.div(row(chevron: false), class: "UnmagicAIChatToolCall__row"),
              (tag.div(safe_join([ rail, @made ]), class: "UnmagicAIChatToolCall__made") if @made.present?)
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # <details> so the disclosure needs no script and no state to restore after
        # a broadcast replaces the row, which happens on every change of state.
        def disclosure(payloads)
          tag.details(open: @open, class: "UnmagicAIChatToolCall__disclosure") do
            safe_join [
              tag.summary(row(chevron: true), class: "UnmagicAIChatToolCall__row"),
              tag.div(safe_join([ rail, *payloads ]), class: "UnmagicAIChatToolCall__body")
            ]
          end
        end

        def row(chevron:)
          safe_join [
            glyph,
            tag.code(@name, class: "UnmagicAIChatToolCall__name"),
            (tag.span(@summary, class: "UnmagicAIChatToolCall__summary") if @summary.present?),
            (Icons.svg(view, :chevron_right, class: "UnmagicAIChatChevron") if chevron),
            readings,
            (progress_line if @state == :running && @progress.present?)
          ].compact
        end

        # A call that simply worked is the common case, so its glyph says what it was
        # about (icon:) rather than repeating a tick down the whole timeline.
        def glyph
          name = @state == :done && @icon ? @icon : GLYPHS.fetch(@state)

          tag.span(class: "UnmagicAIChatToolCall__glyph") do
            safe_join [
              Icons.svg(view, name, class: ("UnmagicAIChatSpinner" if @state == :running)),
              tag.span(AIChat.t("tool_call.#{@state}", default: LABELS.fetch(@state)), class: "UnmagicVisuallyHidden")
            ]
          end
        end

        def readings
          items = [ failures_reading, timing_reading ].compact
          tag.span(safe_join(items), class: "UnmagicAIChatToolCall__readings") if items.any?
        end

        def failures_reading
          return if @failures.to_i.zero? || @state == :failed

          reading(:triangle_alert, AIChat.t("tool_call.partly_failed", default: "Partly failed"),
            AIChat.t("tool_call.failures", count: @failures, default: "%{count} failed"), modifier: "warn")
        end

        def timing_reading
          return unless @timing

          if @state == :running && @timing[:started_at]
            reading(:timer, AIChat.t("tool_call.running_for", default: "Running for"),
              Elapsed.new(view, @timing[:started_at], direction: :up).render)
          elsif @timing[:duration]
            reading(:timer, AIChat.t("tool_call.took", default: "Took"), Duration.format(@timing[:duration]))
          end
        end

        # Each reading leads with a glyph, so a run of small grey numbers can be told
        # apart before the digits are read.
        def reading(icon, label, value, modifier: nil)
          tag.span(class: view.class_names("UnmagicAIChatToolCall__reading",
            "UnmagicAIChatToolCall__reading--#{modifier}" => modifier)) do
            safe_join [ Icons.svg(view, icon), tag.span(label, class: "UnmagicVisuallyHidden"), value ]
          end
        end

        def progress_line
          tag.span(@progress, id: ("#{@id}_progress" if @id), class: "UnmagicAIChatToolCall__progress")
        end

        # The timeline carried down the side of whatever hangs under a row.
        def rail
          tag.span(class: "UnmagicAIChatToolCall__rail", "aria-hidden": "true")
        end
      end
    end
  end
end
