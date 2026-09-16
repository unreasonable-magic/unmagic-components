# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # What an empty conversation says, and the suggestions that start one. See
      # ActionViewHelpers#ai_chat_welcome.
      class Welcome
        Suggestion = Struct.new(:label, :icon, :fill, :value)

        def initialize(view, heading:, heading_tag: :h2, composer: "composer", field: nil, **options)
          @view = view
          @heading = heading
          @heading_tag = heading_tag
          @composer = composer
          @field = field
          @options = options
          @body = nil
          @suggestions = []
        end

        def body(text)
          @body = text
          nil
        end

        # fill: true puts the text in the box without sending it, for a prompt that
        # can't be sent as it stands.
        def suggestion(label, icon: nil, fill: false, value: nil)
          @suggestions << Suggestion.new(label, icon, fill, value)
          nil
        end

        def render
          view.content_tag(:div, **@options, class: view.class_names("UnmagicAIChatWelcome", @options[:class])) do
            safe_join [
              view.content_tag(@heading_tag, @heading, class: "UnmagicAIChatWelcome__heading"),
              (tag.p(@body, class: "UnmagicAIChatWelcome__body") if @body.present?),
              suggestions
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # Buttons, not links: a suggestion puts text in a box on this page.
        def suggestions
          return if @suggestions.empty?

          tag.ul(class: "UnmagicAIChatWelcome__suggestions") do
            safe_join(@suggestions.map do |suggestion|
              tag.li do
                tag.button(type: "button", class: "UnmagicAIChatWelcome__suggestion",
                  data: {
                    ai_chat_suggestion: suggestion.value || suggestion.label,
                    ai_chat_suggestion_form: @composer,
                    ai_chat_suggestion_field: @field,
                    ai_chat_suggestion_fill: ("" if suggestion.fill)
                  }.compact) do
                  safe_join [ (Icons.svg(view, suggestion.icon) if suggestion.icon), suggestion.label ].compact
                end
              end
            end)
          end
        end
      end
    end
  end
end
