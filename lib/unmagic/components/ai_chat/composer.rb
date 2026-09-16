# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The box a person types into, and the one button at the end of it. See
      # ActionViewHelpers#ai_chat_composer.
      class Composer
        STATES = %i[idle running stopping waiting].freeze
        STOP_FORM = "stop_turn"

        class << self
          # The action region on its own: Send, or Stop while a turn runs. Neither
          # button is nested in the form it submits (both name it with form=), which
          # is what lets a broadcast redraw this region without a form builder and
          # without taking the half-typed draft with it.
          def action(view, form:, state:, label: nil, stop_form: STOP_FORM)
            AIChat.validate!("ai_chat_composer", :state, state, STATES)

            view.tag.div(id: "#{form}_action", class: "UnmagicAIChatComposer__action", "aria-live": "polite") do
              case state
              when :idle then send_button(view, form, label)
              when :running then stop_button(view, stop_form)
              when :stopping then stopping_button(view)
              when :waiting
                view.safe_join [
                  view.tag.span(AIChat.t("composer.waiting", default: "Waiting for your input…"),
                    class: "UnmagicAIChatComposer__hint"),
                  stop_button(view, stop_form)
                ]
              end
            end
          end

          private

          def send_button(view, form, label)
            label ||= AIChat.t("composer.send", default: "Send")
            view.tag.button(type: "submit", form: form, class: Button.classes(:primary)) do
              view.safe_join [ view.tag.span(label), Icons.svg(view, :arrow_up) ]
            end
          end

          def stop_button(view, stop_form)
            view.tag.button(type: "submit", form: stop_form,
              class: view.class_names(Button.classes, "UnmagicAIChatComposer__stop")) do
              view.safe_join [ Icons.svg(view, :circle_stop), AIChat.t("composer.stop", default: "Stop") ]
            end
          end

          # Asked, not yet granted: a button still reading Stop looks like one that
          # didn't work, and gets pressed again.
          def stopping_button(view)
            view.tag.button(type: "button", disabled: true, class: Button.classes) do
              view.safe_join [
                Icons.svg(view, :loader_circle, class: "UnmagicAIChatSpinner"),
                AIChat.t("composer.stopping", default: "Stopping…")
              ]
            end
          end
        end

        def initialize(view, form:, field:, state: :idle, label: nil, stop_form: STOP_FORM, placeholder: nil,
          rows: 2, **options)
          form_id = form.options[:id]
          raise ArgumentError, "ai_chat_composer needs its form to have an id: (the Send button names it)" if form_id.blank?

          AIChat.validate!("ai_chat_composer", :state, state, STATES)

          @view = view
          @form = form
          @form_id = form_id.to_s
          @field = field
          @state = state
          @label = label
          @stop_form = stop_form
          @placeholder = placeholder
          @rows = rows
          @options = options
          @optimistic = nil
          @attach = nil
          @menu = nil
          @actions = nil
        end

        # Draw the question into the transcript the moment it's sent, under an id
        # the form mints and the server's own row will come back with.
        def optimistic(id:, container:)
          @optimistic = { id: id, container: container }
          nil
        end

        def attach(content = nil, &block)
          @attach = block ? view.capture(&block) : content
          nil
        end

        def menu(content = nil, &block)
          @menu = block ? view.capture(&block) : content
          nil
        end

        def actions(content = nil, &block)
          @actions = block ? view.capture(&block) : content
          nil
        end

        def render
          box = tag.div(class: "UnmagicAIChatComposer__box") do
            safe_join [
              (view.uuid_input_tag(@optimistic[:id]) if @optimistic),
              field,
              (tag.div(@attach, class: "UnmagicAIChatComposer__attach") if @attach.present?),
              (tag.div(@actions, class: "UnmagicAIChatComposer__actions") if @actions.present?),
              self.class.action(view, form: @form_id, state: @state, label: @label, stop_form: @stop_form)
            ].compact
          end

          view.content_tag(:div, **@options, class: view.class_names("UnmagicAIChatComposer", @options[:class])) do
            safe_join [
              @menu.presence,
              tag.div(class: "UnmagicAIChatComposer__chips", "data-ai-chat-chips": ""),
              (@optimistic ? optimistic_wrapper(box) : box)
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # The textarea is the composer's own chrome rather than a styled control:
        # the box around it is the control and carries the focus ring, so it skips
        # the control_class seam that would give it a border of its own. It is
        # never disabled, whatever the state — only the button changes.
        def field
          label = @placeholder.presence || AIChat.t("composer.label", default: "Message")
          value = @form.object.try(@field) if @form.object.respond_to?(@field)

          Autogrow.wrap(view, view.text_area_tag(@form.field_name(@field), value,
            id: @form.field_id(@field), rows: @rows, required: true, placeholder: @placeholder,
            "aria-label": label, class: "UnmagicAIChatComposer__field", "data-ai-chat-composer-field": ""))
        end

        def optimistic_wrapper(box)
          text = @form.field_name(@field)

          view.content_tag("unmagic-optimistic", container: @optimistic[:container], class: "UnmagicOptimistic") do
            safe_join [
              box,
              tag.template(Message.new(view, role: :user, optimistic: { id: @optimistic[:id], text: text }).render(""))
            ]
          end
        end
      end
    end
  end
end
