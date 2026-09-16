# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # One turn: a user's bubble of plain text, or an assistant's unbubbled
      # prose. See ActionViewHelpers#ai_chat_message.
      class Message
        ROLES = %i[user assistant].freeze

        def initialize(view, role:, id: nil, streaming: false, final: false, optimistic: nil, **options)
          AIChat.validate!("ai_chat_message", :role, role, ROLES)
          if optimistic && role != :user
            raise ArgumentError, "only a user turn can be optimistic (the composer draws what was typed)"
          end
          if optimistic && !(optimistic.key?(:id) && optimistic.key?(:text))
            raise ArgumentError, "optimistic: needs id: and text:, naming the form fields to fill them from"
          end

          @view = view
          @role = role
          @id = id
          @streaming = streaming
          @final = final
          @optimistic = optimistic
          @options = options
          @reasoning = nil
          @actions = nil
          @branches = nil
          @attachments = nil
        end

        # A collapsed "thought process" above the body. Takes ai_chat_reasoning's
        # options; the body is the block.
        def reasoning(content = nil, **options, &block)
          @reasoning = Reasoning.new(view, id: ("#{@id}_reasoning" if @id), **options)
            .render(block ? view.capture(&block) : content)
          nil
        end

        def actions(content = nil, &block)
          @actions = block ? view.capture(&block) : content
          nil
        end

        def branches(content = nil, &block)
          @branches = block ? view.capture(&block) : content
          nil
        end

        # Above a user's bubble, which is the order it happened in.
        def attachments(content = nil, &block)
          @attachments = block ? view.capture(&block) : content
          nil
        end

        def render(body)
          @role == :user ? user(body) : assistant(body)
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def user(body)
          data = @optimistic ? { optimistic_id: @optimistic[:id], optimistic: "" } : {}

          root(data: data) do
            safe_join [
              role_label,
              (tag.div(@attachments, class: "UnmagicAIChatMessage__attachments") if @attachments.present?),
              tag.div(@optimistic ? "" : trimmed(body), class: "UnmagicAIChatMessage__bubble",
                data: (@optimistic ? { optimistic_text: @optimistic[:text] } : {})),
              footer
            ].compact
          end
        end

        # A settled turn with nothing to say is hidden rather than dropped, so a
        # broadcast can still key on its id. A turn still streaming is never empty:
        # it shows the thinking spinner until its first token replaces it.
        def assistant(body)
          blank = body.blank? && @reasoning.blank? && !@streaming

          root(hidden: blank) do
            safe_join [ role_label, @reasoning.presence, content(body), footer ].compact
          end
        end

        # The body is always the streaming element when the turn has an id, even once
        # it has settled: the settled render upserts over the streaming one, and the
        # element carries the reveal across that swap.
        def content(body)
          body = thinking if body.blank? && @streaming && !@final
          return tag.div(body, class: "UnmagicAIChatMessage__body UnmagicProse") unless @id

          StreamingMarkdown.new(view, id: "#{@id}_content", final: @final, streaming: @streaming,
            class: "UnmagicAIChatMessage__body UnmagicProse").render(body)
        end

        # The bubble keeps the line breaks that were typed, so a block's own leading
        # newline and indentation would show as a blank first line. Trimming the ends
        # can't make markup, so already-escaped content stays safe.
        def trimmed(body)
          return body.to_s.strip unless body.respond_to?(:html_safe?) && body.html_safe?

          body.to_str.strip.html_safe # rubocop:disable Rails/OutputSafety -- escaped content, only whitespace removed
        end

        def thinking
          tag.span(class: "UnmagicAIChatMessage__thinking") do
            safe_join [
              Icons.svg(view, :loader_circle, class: "UnmagicAIChatSpinner"),
              tag.span(AIChat.t("message.thinking", default: "Thinking"), class: "UnmagicVisuallyHidden")
            ]
          end
        end

        def footer
          return if @actions.blank? && @branches.blank?

          tag.div(safe_join([ @branches.presence, @actions.presence ].compact), class: "UnmagicAIChatMessage__footer")
        end

        def role_label
          default = @role == :user ? "You said" : "Assistant said"
          tag.span(AIChat.t("message.#{@role}", default: default), class: "UnmagicVisuallyHidden")
        end

        def root(hidden: false, data: {}, &block)
          view.content_tag(:div, **@options,
            id: (@id unless @optimistic),
            hidden: hidden,
            data: data.merge(@options[:data] || {}),
            class: view.class_names("UnmagicAIChatMessage", "UnmagicAIChatMessage--#{@role}", @options[:class]), &block)
        end
      end
    end
  end
end
