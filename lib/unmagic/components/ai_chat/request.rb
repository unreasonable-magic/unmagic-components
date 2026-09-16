# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The agent asking something it can't work out on its own, with the answers
      # right there. One component, two faces: choices, or a form the caller
      # builds. See ActionViewHelpers#ai_chat_request.
      class Request
        STATES = %i[waiting accepted declined cancelled timed_out].freeze

        OUTCOMES = { accepted: "Submitted", declined: "Declined", cancelled: "Cancelled",
                     timed_out: "Timed out" }.freeze

        OUTCOME_ICONS = { accepted: :circle_check, declined: :ban, cancelled: :circle_x, timed_out: :clock }.freeze

        Question = Struct.new(:text, :header, :multiple, :options, :picked)
        Option = Struct.new(:label, :description)

        # Collects a question's options.
        class QuestionBuilder
          attr_reader :options

          def initialize
            @options = []
          end

          def option(label, description: nil)
            @options << Option.new(label, description)
            nil
          end
        end

        def initialize(view, state:, url: nil, method: :patch, prompt: nil, label: nil, scope: :response,
          live: false, **options)
          AIChat.validate!("ai_chat_request", :state, state, STATES)
          raise ArgumentError, "a waiting ai_chat_request needs a url: to answer to" if state == :waiting && url.blank?

          @view = view
          @state = state
          @url = url
          @method = method
          @prompt = prompt
          @label = label
          @scope = scope
          @live = live
          @options = options
          @questions = []
          @form = nil
          @answers = []
          @decline = nil
          @aside = nil
        end

        # picked: is what was chosen, for an answered request; the options go, and
        # the question stays, because it is most of what the card is worth later.
        def question(text, header: nil, multiple: false, picked: nil, &block)
          builder = QuestionBuilder.new
          view.capture(builder, &block) if block # capture, so the block's own whitespace stays out of the page
          @questions << Question.new(text, header, multiple, builder.options, Array(picked))
          nil
        end

        # The caller's own fields, given the form builder while waiting.
        def form(&block)
          @form = block
          nil
        end

        # What was sent back, for an answered form.
        def answer(label, value)
          @answers << [ label, value ]
          nil
        end

        def decline(label = nil)
          @decline = label || AIChat.t("request.decline", default: "Decline")
          nil
        end

        def aside(text)
          @aside = text
          nil
        end

        def render
          raise ArgumentError, "an ai_chat_request asks with questions or a form, not both" if @questions.any? && @form

          view.content_tag(:div, **@options,
            role: ("alert" if @live && waiting?),
            class: view.class_names("UnmagicAIChatRequest", "UnmagicAIChatRequest--#{@state}", @options[:class])) do
            safe_join [ head, (tag.p(@prompt, class: "UnmagicAIChatRequest__prompt") if @prompt.present?), body ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def waiting? = @state == :waiting

        # Past tense once answered: a heading still saying somebody wants something
        # would be the one line in the card that's no longer true.
        def head
          tag.div(class: "UnmagicAIChatRequest__head") do
            safe_join [
              Icons.svg(view, :circle_question_mark),
              tag.span(waiting? ? AIChat.t("request.waiting", default: "Wants to know") : AIChat.t("request.asked", default: "Wanted to know")),
              (outcome unless waiting?)
            ].compact
          end
        end

        def outcome
          tag.span(class: "UnmagicAIChatRequest__outcome") do
            safe_join [ Icons.svg(view, OUTCOME_ICONS.fetch(@state)), AIChat.t("request.#{@state}", default: OUTCOMES.fetch(@state)) ]
          end
        end

        def body
          if waiting?
            view.form_with(url: @url, method: @method, scope: @scope, builder: Components::FormBuilder,
              class: "UnmagicAIChatRequest__form") do |form|
              safe_join [ questions, (view.capture(form, &@form) if @form), actions ].compact
            end
          else
            safe_join [ questions, answers ].compact
          end
        end

        def questions
          return if @questions.empty?

          safe_join(@questions.each_with_index.map { |question, index| fieldset(question, index) })
        end

        def fieldset(question, index)
          tag.fieldset(class: "UnmagicAIChatRequest__question") do
            safe_join [
              tag.legend(class: "UnmagicAIChatRequest__legend") do
                safe_join [
                  (tag.span(question.header, class: "UnmagicAIChatRequest__header") if question.header.present?),
                  tag.span(question.text, class: "UnmagicAIChatRequest__label")
                ].compact
              end,
              waiting? ? choices(question, index) : picked(question)
            ]
          end
        end

        # A single choice is required, so a question skipped by accident isn't one
        # the agent has to ask again.
        def choices(question, index)
          kind = question.multiple ? :check : :radio

          tag.div(class: "UnmagicAIChatRequest__options") do
            safe_join(question.options.map do |option|
              tag.label(class: "UnmagicAIChatRequest__option") do
                safe_join [
                  tag.input(type: question.multiple ? "checkbox" : "radio", name: "answers[#{index}][]",
                    value: option.label, required: !question.multiple, class: Control.classes(view, kind)),
                  tag.span(class: "UnmagicAIChatRequest__choice") do
                    safe_join [
                      tag.span(option.label, class: "UnmagicAIChatRequest__choiceLabel"),
                      (tag.span(option.description, class: "UnmagicAIChatRequest__choiceDescription") if option.description.present?)
                    ].compact
                  end
                ]
              end
            end)
          end
        end

        def picked(question)
          text = question.picked.presence&.to_sentence || AIChat.t("request.unanswered", default: "No answer.")
          tag.p(text, class: view.class_names("UnmagicAIChatRequest__picked",
            "UnmagicAIChatRequest__picked--none" => question.picked.empty?))
        end

        def answers
          return if @answers.empty?

          tag.dl(class: "UnmagicAIChatRequest__answers") do
            safe_join(@answers.map do |label, value|
              tag.div(safe_join([ tag.dt(label), tag.dd(value) ]), class: "UnmagicAIChatRequest__answer")
            end)
          end
        end

        # Decline posts the same form with a flag and skips validation, so it is one
        # form with no nested button_to and needs nothing filled in.
        def actions
          tag.div(class: "UnmagicAIChatRequest__actions") do
            safe_join [
              tag.button(@label || AIChat.t("request.answer", default: "Answer"), type: "submit", class: Button.classes(:primary)),
              (tag.button(@decline, type: "submit", name: "decline", value: "1", formnovalidate: true, class: Button.classes) if @decline),
              (tag.p(@aside, class: "UnmagicAIChatRequest__aside") if @aside.present?)
            ].compact
          end
        end
      end
    end
  end
end
