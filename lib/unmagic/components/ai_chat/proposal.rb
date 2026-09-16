# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # An offer the agent made in passing, with its actions while pending, settling
      # into a quiet decided state. It doesn't stop the work. See
      # ActionViewHelpers#ai_chat_proposal.
      class Proposal
        STATES = %i[pending accepted rejected].freeze

        OUTCOMES = { accepted: "Saved", rejected: "Dismissed" }.freeze

        def initialize(view, state: :pending, icon: :lightbulb, id: nil, **options)
          AIChat.validate!("ai_chat_proposal", :state, state, STATES)

          @view = view
          @state = state
          @icon = icon
          @id = id
          @options = options
          @claim = nil
          @meta = nil
          @accept = nil
          @reject = nil
          @outcome = nil
        end

        def claim(content = nil, &block)
          @claim = block ? view.capture(&block) : content
          nil
        end

        def meta(text)
          @meta = text
          nil
        end

        def accept(content = nil, &block)
          @accept = block ? view.capture(&block) : content
          nil
        end

        def reject(content = nil, &block)
          @reject = block ? view.capture(&block) : content
          nil
        end

        def outcome(text)
          @outcome = text
          nil
        end

        # An <aside> named by its claim, so a reader tabbing through a reply hears
        # what each card offers before reaching its buttons.
        def render
          claim_id = "#{@id || AIChat.random_id("proposal")}_claim"

          view.content_tag(:aside, **@options,
            id: @id,
            "aria-labelledby": claim_id,
            class: view.class_names("UnmagicAIChatProposal", "UnmagicAIChatProposal--#{@state}", "not-prose", @options[:class])) do
            safe_join [
              tag.div(class: "UnmagicAIChatProposal__body") do
                safe_join [
                  Icons.svg(view, @icon, class: "UnmagicAIChatProposal__glyph"),
                  tag.div do
                    safe_join [
                      tag.p(@claim, id: claim_id, class: "UnmagicAIChatProposal__claim"),
                      (tag.p(@meta, class: "UnmagicAIChatProposal__meta") if @meta.present?)
                    ].compact
                  end
                ]
              end,
              side
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def side
          if @state == :pending
            actions = [ @accept, @reject ].select(&:present?)
            tag.div(safe_join(actions), class: "UnmagicAIChatProposal__actions") if actions.any?
          else
            tag.span(class: "UnmagicAIChatProposal__outcome") do
              safe_join [
                Icons.svg(view, @state == :accepted ? :check : :x),
                @outcome || AIChat.t("proposal.#{@state}", default: OUTCOMES.fetch(@state))
              ]
            end
          end
        end
      end
    end
  end
end
