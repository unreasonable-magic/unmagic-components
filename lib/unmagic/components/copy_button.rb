# frozen_string_literal: true

module Unmagic
  module Components
    # A button that copies text to the clipboard. See ActionViewHelpers#copy_button.
    class CopyButton
      def initialize(view, text:, from:, label:, **options)
        raise ArgumentError, "copy_button needs the text to copy, or from: an element id" if text.nil? && from.nil?

        @view = view
        @text = text
        @from = from
        @label = label || I18n.t("unmagic.components.clipboard.copy", default: "Copy")
        @options = options
      end

      # The live region says "Copied" for a screen reader, since the icon swap is
      # only seen.
      def render(content)
        copied = I18n.t("unmagic.components.clipboard.copied", default: "Copied")

        view.content_tag("unmagic-clipboard", value: @text, for: @from, class: "UnmagicClipboard",
          data: { copied_label: copied }) do
          safe_join [ button(content), tag.span(class: "UnmagicVisuallyHidden", "aria-live": "polite") ]
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def button(content)
        if content
          tag.button(content, type: "button", **@options,
            class: view.class_names(Button.classes, "UnmagicClipboard__button", @options[:class]))
        else
          tag.button(type: "button", **@options, "aria-label": @label, title: @label,
            class: view.class_names(Button.classes(:icon), "UnmagicClipboard__button", @options[:class])) do
            safe_join [
              Icons.svg(view, :copy, class: "UnmagicClipboard__idle"),
              Icons.svg(view, :check, class: "UnmagicClipboard__done")
            ]
          end
        end
      end
    end
  end
end
