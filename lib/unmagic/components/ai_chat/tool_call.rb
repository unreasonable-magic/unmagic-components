# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # One reach for a tool, from the ask through to the answer, as a row in a
      # timeline. See ActionViewHelpers#ai_chat_tool_call.
      #
      # The markup is HTML a person could write: a <details> fold whose <summary>
      # is the row, payloads inside the fold as <figure>s, and the result after it.
      # Ruby renders the facts and the translated words; CSS reads the state off
      # the host's attribute; the element keeps the glyph true to it.
      class ToolCall
        STATES = %i[queued running waiting done failed].freeze

        LABELS = { queued: "Queued", running: "Running", waiting: "Waiting on you", done: "Done",
                   failed: "Failed" }.freeze

        # The glyph for each state, matching tool_call_icons.js. Change both together.
        GLYPHS = { queued: :circle_dashed, running: :loader_circle, waiting: :circle_question_mark,
                   done: :check, failed: :circle_x }.freeze

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

        # What the tool is saying while it works. An <output> in the row, which the
        # host updates as reports come in.
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
          view.content_tag("unmagic-tool-call", **@options, **labels, id: @id, state: @state,
            "aria-busy": ("true" if @state == :running),
            data: { ai_chat_timeline: ("row" if @timeline) }.merge(@options[:data] || {})) do
            safe_join [
              tag.details(open: @open) do
                safe_join [ row, *@payloads.map(&:render).select(&:present?) ]
              end,
              (tag.div(@made) if @made.present?)
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # Every state's word, for the element to relabel the glyph with later.
        def labels
          LABELS.to_h { |state, fallback| [ "label-#{state}", AIChat.t("tool_call.#{state}", default: fallback) ] }
        end

        # The fold is always rendered, even with nothing to show yet: a <summary>
        # means nothing outside a <details>, and a queued call's payloads arrive
        # into it. The element keeps an empty fold out of the way.
        def row
          tag.summary do
            safe_join [
              glyph,
              tag.code(@name),
              (tag.span(@summary) if @summary.present?),
              *readings,
              (tag.output(@progress) if @progress.present?)
            ].compact
          end
        end

        # The one node the element owns, seeded here so the state is read before
        # any script runs. It carries the state it was drawn for, so the element
        # redraws it only when that changes, and keeps the done icon in a template
        # for a call that gets there later.
        def glyph
          tag.span("data-tool-call-glyph": @state) do
            safe_join [
              @state == :done ? done_icon(class: "UnmagicIcon") : Icons.svg(view, GLYPHS.fetch(@state),
                class: ("UnmagicAIChatSpinner" if @state == :running)),
              (tag.template(done_icon) if @icon && @state != :done),
              tag.span(labels.fetch("label-#{@state}"), class: "UnmagicVisuallyHidden")
            ].compact
          end
        end

        def done_icon(**options) = Icons.svg(view, @icon || GLYPHS.fetch(:done), **options)

        # Each reading is the element it is, and CSS shows or hides it by state.
        # Each leads with a glyph, so a run of small grey numbers can be told apart
        # before the digits are read.
        def readings
          parts = []
          unless @failures.to_i.zero?
            parts << tag.data(value: @failures) do
              reading(:triangle_alert, AIChat.t("tool_call.partly_failed", default: "Partly failed"),
                AIChat.t("tool_call.failures", count: @failures, default: "%{count} failed"))
            end
          end
          if @timing&.dig(:started_at)
            parts << Elapsed.new(view, @timing[:started_at], direction: :up).render do |clock|
              reading(:timer, AIChat.t("tool_call.running_for", default: "Running for"), clock)
            end
          end
          if @timing&.dig(:duration)
            parts << tag.time(datetime: format("PT%gS", @timing[:duration].to_f)) do
              reading(:timer, AIChat.t("tool_call.took", default: "Took"), Duration.format(@timing[:duration]))
            end
          end
          parts
        end

        def reading(icon, label, value)
          safe_join [ Icons.svg(view, icon), tag.span(label, class: "UnmagicVisuallyHidden"), value ]
        end

        # The same parts as streams, for TurboStreamActions#ai_chat_tool_call. Each
        # part is addressed by what it is under the host's id, so the markup's
        # shape stays the gem's business.
        class Stream
          attr_reader :streams

          def initialize(builder, view, id)
            @builder = builder
            @view = view
            @id = id
            @streams = []
          end

          def asked(payload, **options)
            append_payload(payload, AIChat.t("tool_call.asked", default: "Asked"), **options)
          end

          def answered(payload, **options)
            append_payload(payload, AIChat.t("tool_call.answered", default: "Answered"), **options)
          end

          def progress(text)
            @streams << @builder.update_all("##{@id} > details > summary > output", text)
            nil
          end

          def made(content = nil, &block)
            content = @view.capture(&block) if block
            @streams << @builder.append(@id, @view.tag.div(content))
            nil
          end

          def state(state)
            AIChat.validate!("ai_chat_tool_call", :state, state, STATES)
            @streams << @view.turbo_stream_action_tag(:tool_call_state, targets: "##{@id}", state: state)
            nil
          end

          private

          def append_payload(payload, label, **options)
            markup = Payload.new(@view, payload, label: label, **options).render
            @streams << @builder.append_all("##{@id} > details", markup) if markup.present?
            nil
          end
        end
      end
    end
  end
end
