# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # Walking between alternative versions of a turn. It renders counts and
      # follows links; what a branch is stays the host's business. See
      # ActionViewHelpers#ai_chat_branch_picker.
      class BranchPicker
        def initialize(view, index:, count:, previous: nil, next: nil, method: :get, **options)
          raise ArgumentError, "ai_chat_branch_picker count must be at least 1 (got #{count.inspect})" unless count.to_i >= 1
          unless (1..count).cover?(index)
            raise ArgumentError, "ai_chat_branch_picker index #{index.inspect} is outside 1..#{count}"
          end

          @view = view
          @index = index
          @count = count
          @previous = previous
          @next = binding.local_variable_get(:next)
          @method = method
          @options = options
        end

        # One version isn't a branch, and a 1/1 on every turn is noise on every turn.
        def render
          return "".html_safe if @count == 1

          label = AIChat.t("branch_picker.label", index: @index, count: @count, default: "Version %{index} of %{count}")

          view.content_tag(:div, **@options, role: "group", "aria-label": label,
            class: view.class_names("UnmagicAIChatBranchPicker", @options[:class])) do
            safe_join [
              step(@previous, :chevron_left, AIChat.t("branch_picker.previous", default: "Previous version")),
              tag.span("#{@index}/#{@count}", class: "UnmagicAIChatBranchPicker__count", "aria-hidden": "true"),
              step(@next, :chevron_right, AIChat.t("branch_picker.next", default: "Next version"))
            ]
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # An end with nowhere to go is a span, not a disabled link: there's no such
        # thing, and it would be a lie to the keyboard.
        def step(url, icon, label)
          classes = "UnmagicAIChatBranchPicker__step"
          glyph = Icons.svg(view, icon)

          if url.nil?
            tag.span(glyph, "aria-disabled": "true", title: label, class: classes)
          elsif @method == :get
            view.link_to(glyph, url, "aria-label": label, title: label, class: classes)
          else
            view.button_to(url, method: @method, "aria-label": label, title: label, class: classes,
              form: { class: "UnmagicAIChatBranchPicker__form" }) { glyph }
          end
        end
      end
    end
  end
end
