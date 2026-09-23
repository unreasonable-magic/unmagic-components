# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # One turn: a user's bubble of plain text, or an assistant's unbubbled
      # prose. A Messaging::Message (a bubble of the reader's own, or a row with
      # no avatar) that adds what an agent's turn needs: a body that streams, a
      # thinking spinner, the optimistic template, the reasoning above the reply
      # and the branch picker under it. See ActionViewHelpers#ai_chat_message.
      class Message < Messaging::Message
        ROLES = %i[user assistant].freeze

        def initialize(view, role:, id: nil, streaming: false, final: false, optimistic: nil, **options)
          AIChat.validate!("ai_chat_message", :role, role, ROLES)
          if optimistic && role != :user
            raise ArgumentError, "only a user turn can be optimistic (the composer draws what was typed)"
          end
          if optimistic && !(optimistic.key?(:id) && optimistic.key?(:text))
            raise ArgumentError, "optimistic: needs id: and text:, naming the form fields to fill them from"
          end

          @role = role
          @streaming = streaming
          @final = final
          @optimistic = optimistic
          @reasoning = nil
          @branches = nil
          super(view, variant: (role == :user ? :bubble : :row), own: role == :user, id: id, **options)
        end

        # A collapsed "thought process" above the body. Takes ai_chat_reasoning's
        # options; the body is the block.
        def reasoning(content = nil, **options, &block)
          @reasoning = Reasoning.new(view, id: ("#{@id}_reasoning" if @id), **options)
            .render(block ? view.capture(&block) : content)
          nil
        end

        def branches(content = nil, &block)
          @branches = block ? view.capture(&block) : content
          nil
        end

        # The bar goes in this turn's own footer, beside the branch picker, rather
        # than where a row would float it.
        def actions(content = nil, &block)
          @actions = block ? view.capture(&block) : content
          nil
        end

        def render(body)
          super(@optimistic ? "" : body)
        end

        private

        # A settled assistant turn with nothing to say is hidden rather than
        # dropped, so a broadcast can still key on its id. The optimistic template
        # leaves the id for <unmagic-optimistic> to fill.
        def root_attributes(body)
          attributes = super
          hidden = @role == :assistant && body.blank? && @reasoning.blank? && !@streaming
          data = @optimistic ? { optimistic_id: @optimistic[:id], optimistic: "" } : {}

          attributes.merge(id: (@id unless @optimistic), hidden: hidden, data: attributes[:data].merge(data))
        end

        def extra_root_classes = [ "UnmagicAIChatMessage", "UnmagicAIChatMessage--#{@role}" ]

        # Every turn says whose it is: the only way a non-visual reader can tell a
        # bubble from prose.
        def speaker_label
          default = @role == :user ? "You said" : "Assistant said"
          tag.span(AIChat.t("message.#{@role}", default: default), class: "UnmagicVisuallyHidden")
        end

        def before_body = @reasoning.presence

        # An assistant's body is always the streaming element when the turn has an
        # id, even once it has settled: the settled render upserts over the
        # streaming one, and the element carries the reveal across that swap. A
        # turn still streaming is never empty: it shows the thinking spinner until
        # its first token replaces it.
        def body_element(body)
          if @role == :user
            data = @optimistic ? { optimistic_text: @optimistic[:text] } : {}
            return tag.div(body, class: "UnmagicMessage__body", data: data)
          end

          body = thinking if body.blank? && @streaming && !@final
          return tag.div(body, class: "UnmagicMessage__body UnmagicProse") unless @id

          StreamingMarkdown.new(view, id: "#{@id}_content", final: @final, streaming: @streaming,
            class: "UnmagicMessage__body UnmagicProse").render(body)
        end

        def thinking
          tag.span(class: "UnmagicAIChatMessage__thinking") do
            safe_join [
              Icons.svg(view, :loader_circle, class: "UnmagicAIChatSpinner"),
              tag.span(AIChat.t("message.thinking", default: "Thinking"), class: "UnmagicVisuallyHidden")
            ]
          end
        end

        def footer_element
          return if @actions.blank? && @branches.blank?

          tag.div(safe_join([ @branches.presence, @actions.presence ].compact), class: "UnmagicAIChatMessage__footer")
        end

        def actions_cell = nil
      end
    end
  end
end
