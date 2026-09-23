# frozen_string_literal: true

module Unmagic
  module Components
    module Messaging
      # Someone is writing: three dots in a bubble, with the writer's name. See
      # ActionViewHelpers#message_typing.
      class Typing
        def initialize(view, who = nil, avatar: nil, **options)
          @view = view
          @who = who
          @avatar = avatar
          @options = options
        end

        # No live region of its own: a live thread announces its arrival, and a
        # nested one would say it twice. The dots and the visible name are hidden
        # from assistive tech, so the sentence is the only text a reader hears.
        def render
          view.content_tag(:div, **@options, class: view.class_names("UnmagicMessageTyping", @options[:class])) do
            safe_join [
              (tag.div(Messaging.avatar(view, @avatar, author: @who, size: :small), class: "UnmagicMessageTyping__avatar") if @avatar),
              tag.div(class: "UnmagicMessageTyping__main") do
                safe_join [
                  (tag.span(@who, class: "UnmagicMessageTyping__author", "aria-hidden": "true") if @who.present?),
                  tag.span(safe_join([ tag.i, tag.i, tag.i ]), class: "UnmagicMessageTyping__bubble", "aria-hidden": "true"),
                  tag.span(sentence, class: "UnmagicVisuallyHidden")
                ].compact
              end
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def sentence
          if @who.present?
            Messaging.t("typing.named", name: @who, default: "%{name} is typing")
          else
            Messaging.t("typing.anonymous", default: "Typing")
          end
        end
      end
    end
  end
end
