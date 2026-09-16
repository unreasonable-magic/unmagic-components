# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The controls under a turn: copy it, run it again, edit it. See
      # ActionViewHelpers#ai_chat_action_bar.
      class ActionBar
        REVEALS = %i[hover always].freeze

        def initialize(view, for:, reveal: :hover, **options)
          target = binding.local_variable_get(:for)
          raise ArgumentError, "ai_chat_action_bar needs for: the id of the turn it acts on" if target.blank?

          AIChat.validate!("ai_chat_action_bar", :reveal, reveal, REVEALS)

          @view = view
          @for = target
          @reveal = reveal
          @options = options
          @controls = []
        end

        def copy(text)
          @controls << view.copy_button(text, class: "UnmagicAIChatActionBar__action")
          nil
        end

        # Every control is icon-only, so each carries a label and a matching title.
        # A GET is a link; anything else is a button_to.
        def action(label, url, icon:, method: :get, confirm: nil, **options)
          content = Icons.svg(view, icon)
          html = options.merge("aria-label": label, title: label,
            class: view.class_names(Button.classes(:icon), "UnmagicAIChatActionBar__action", options[:class]))

          @controls << if method == :get
            view.link_to(content, url, **html)
          else
            view.button_to(url, method: method, form: { data: { turbo_confirm: confirm }.compact, class: "UnmagicAIChatActionBar__form" }, **html) { content }
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
            "aria-label": AIChat.t("action_bar.label", default: "Message actions"),
            "aria-controls": @for,
            data: { reveal: @reveal }.merge(@options[:data] || {}),
            class: view.class_names("UnmagicAIChatActionBar", @options[:class]))
        end

        private

        attr_reader :view

        delegate :safe_join, to: :view, private: true
      end
    end
  end
end
