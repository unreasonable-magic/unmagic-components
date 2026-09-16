# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The checklist an agent is working through. See
      # ActionViewHelpers#ai_chat_plan.
      class Plan
        STATES = %i[pending in_progress waiting completed].freeze

        # The glyph each state leads with. Waiting is the one in colour: the only
        # state that won't move on its own.
        GLYPHS = { pending: :circle_dashed, in_progress: :loader_circle, waiting: :circle_question_mark,
                   completed: :circle_check }.freeze

        LABELS = { pending: "To do", in_progress: "In progress", waiting: "Waiting on you", completed: "Done" }.freeze

        Step = Struct.new(:title, :state, :detail)

        def initialize(view, title: nil, completed: nil, total: nil, open: true, empty: nil, collapsible: true,
          title_tag: :h2, **options)
          @view = view
          @title = title || AIChat.t("plan.title", default: "Plan")
          @completed = completed
          @total = total
          @open = open
          @empty = empty
          @collapsible = collapsible
          @title_tag = title_tag
          @options = options
          @steps = []
        end

        def step(title, state: :pending, &block)
          AIChat.validate!("ai_chat_plan step", :state, state, STATES)

          @steps << Step.new(title, state, (view.capture(&block) if block))
          nil
        end

        def render
          Section.new(view, block: "UnmagicAIChatPlan", icon: :list_checks, title: @title, count: count,
            open: @open, collapsible: @collapsible, title_tag: @title_tag, options: @options).render(body)
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # Given rather than counted when a panel shows only some of the steps, so the
        # reading isn't worked out from the visible few.
        def count
          total = @total || @steps.size
          return if total.zero?

          "#{@completed || @steps.count { |step| step.state == :completed }}/#{total}"
        end

        def body
          if @steps.empty?
            tag.p(@empty || AIChat.t("plan.empty", default: "Nothing planned yet."), class: "UnmagicAIChatPlan__empty")
          else
            tag.ol(safe_join(@steps.map { |step| item(step) }), class: "UnmagicAIChatPlan__steps")
          end
        end

        def item(step)
          tag.li(class: "UnmagicAIChatPlan__step", data: { state: step.state }) do
            safe_join [
              tag.span(class: "UnmagicAIChatPlan__glyph") do
                safe_join [
                  Icons.svg(view, GLYPHS.fetch(step.state),
                    class: ("UnmagicAIChatSpinner" if step.state == :in_progress)),
                  tag.span(AIChat.t("plan.#{step.state}", default: LABELS.fetch(step.state)), class: "UnmagicVisuallyHidden")
                ]
              end,
              tag.div(class: "UnmagicAIChatPlan__text") do
                safe_join [
                  tag.span(step.title, class: "UnmagicAIChatPlan__label"),
                  (tag.div(step.detail, class: "UnmagicAIChatPlan__detail") if step.detail.present?)
                ].compact
              end
            ]
          end
        end
      end
    end
  end
end
