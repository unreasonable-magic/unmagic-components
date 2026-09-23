# frozen_string_literal: true

require "active_support/core_ext/array/conversions"

module Unmagic
  module Components
    module Messaging
      # The emoji people have put on a message, each with its count, and a
      # button to add one. See ActionViewHelpers#message_reactions.
      class Reactions
        def initialize(view, label: nil, **options)
          @view = view
          @label = label
          @options = options
          @items = []
        end

        # With a url: a form that toggles it, pressed when the viewer is among
        # those who reacted; without, a pill that only shows.
        def reaction(emoji, count: 1, reacted: false, names: [], url: nil, method: :post, **options)
          title = Array(names).map(&:to_s).to_sentence if names.present?
          content = safe_join [
            tag.span(emoji, class: "UnmagicMessageReactions__emoji"),
            tag.span(count, class: "UnmagicMessageReactions__count")
          ]
          classes = view.class_names("UnmagicMessageReactions__reaction", options[:class])

          @items << if url
            view.button_to(url, method: method, form: { class: "UnmagicMessageReactions__form" }, **options,
              title: title, "aria-pressed": reacted.to_s, class: classes) { content }
          else
            reacted_label = tag.span(Messaging.t("reactions.reacted", default: "You reacted"), class: "UnmagicVisuallyHidden") if reacted
            tag.span(safe_join([ content, reacted_label ].compact), **options, title: title,
              "data-reacted": ("" if reacted), class: classes)
          end
          nil
        end

        # The way to add one: an icon button the host wires to its picker through
        # the options (popovertarget:, data:), or markup of the host's own.
        def add(content = nil, **options, &block)
          @items << if block || content
            block ? view.capture(&block) : content
          else
            label = Messaging.t("reactions.add", default: "Add reaction")
            tag.button(Icons.svg(view, :smile_plus), type: "button", **options, "aria-label": label, title: label,
              class: view.class_names(Button.classes(:icon), "UnmagicMessageReactions__add", options[:class]))
          end
          nil
        end

        def render
          return "".html_safe if @items.empty?

          view.content_tag(:ul, **@options,
            "aria-label": @label || Messaging.t("reactions.label", default: "Reactions"),
            class: view.class_names("UnmagicMessageReactions", @options[:class])) do
            safe_join(@items.map { |item| tag.li(item) })
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true
      end
    end
  end
end
