# frozen_string_literal: true

module Unmagic
  module Components
    module Messaging
      # The controls on a message: reply, react, copy, edit, delete. A toolbar
      # with one Tab stop, shown on hover or always. See
      # ActionViewHelpers#message_actions; ai_chat_action_bar is the same thing.
      class Actions
        REVEALS = %i[hover always].freeze

        def initialize(view, for:, reveal: :hover, label: nil, **options)
          target = binding.local_variable_get(:for)
          raise ArgumentError, "message_actions needs for: the id of the message it acts on" if target.blank?

          Messaging.validate!("message_actions", :reveal, reveal, REVEALS)

          @view = view
          @for = target
          @reveal = reveal
          @label = label
          @options = options
          @controls = []
        end

        def copy(text)
          @controls << view.copy_button(text, class: "UnmagicMessageActions__action")
          nil
        end

        # Every control is icon-only, so each carries a label and a matching title.
        # A GET is a link; anything else is a button_to.
        def action(label, url, icon:, method: :get, confirm: nil, **options)
          content = Icons.svg(view, icon)
          html = options.merge("aria-label": label, title: label,
            class: view.class_names(Button.classes(:icon), "UnmagicMessageActions__action", options[:class]))

          @controls << if method == :get
            view.link_to(content, url, **html)
          else
            view.button_to(url, method: method, form: { data: { turbo_confirm: confirm }.compact, class: "UnmagicMessageActions__form" }, **html) { content }
          end
          nil
        end

        def control(content = nil, &block)
          @controls << (block ? view.capture(&block) : content)
          nil
        end

        # Hidden with opacity, never display: none, so the bar stays in the tab order
        # and appears the moment it takes focus.
        def render
          return "".html_safe if @controls.empty?

          view.content_tag("unmagic-toolbar", safe_join(@controls), **@options,
            role: "toolbar",
            "aria-label": @label || label,
            "aria-controls": @for,
            data: { reveal: @reveal }.merge(@options[:data] || {}),
            class: view.class_names("UnmagicMessageActions", @options[:class]))
        end

        private

        attr_reader :view

        delegate :safe_join, to: :view, private: true

        # The old AI chat key is tried first, so a host that translated it keeps its
        # translation.
        def label
          Messaging.t("actions.label", default: [ :"unmagic.components.ai_chat.action_bar.label", "Message actions" ])
        end
      end
    end
  end
end
