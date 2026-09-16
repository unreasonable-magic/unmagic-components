# frozen_string_literal: true

require "json"

module Unmagic
  module Components
    module AIChat
      # What went into a tool call or came back out of it, to be read exactly as it
      # was written. See ActionViewHelpers#ai_chat_payload.
      class Payload
        def initialize(view, payload, label: nil, language: nil, duration: nil, copy: false, **options)
          @view = view
          @payload = payload
          @label = label
          @language = language
          @duration = duration
          @copy = copy
          @options = options
        end

        # An absent payload renders nothing, not a dash: a response that hasn't
        # arrived isn't an empty one.
        def render
          return "".html_safe if @payload.nil?

          source, language = formatted

          view.content_tag(:div, **@options, class: view.class_names("UnmagicAIChatPayload", @options[:class])) do
            safe_join [ head(source), code(source, language) ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # Structured data is laid out a key to a line; a string that turns out to be
        # JSON is too. Anything else is shown as the text it is rather than being
        # mis-tokenised.
        def formatted
          return [ @payload.to_s, @language ] if @language && !structured?(@payload)

          value = @payload.is_a?(String) ? parse(@payload) : @payload
          if structured?(value)
            [ JSON.pretty_generate(value), @language || :json ]
          else
            [ @payload.to_s, @language || :plaintext ]
          end
        end

        def structured?(value) = value.is_a?(Hash) || value.is_a?(Array)

        def parse(string)
          JSON.parse(string)
        rescue JSON::ParserError
          string
        end

        def head(source)
          return if @label.blank? && @duration.nil? && !@copy

          tag.div(class: "UnmagicAIChatPayload__head") do
            safe_join [
              tag.span(@label, class: "UnmagicAIChatPayload__label"),
              (timing if @duration),
              (view.copy_button(source, class: "UnmagicAIChatPayload__copy") if @copy)
            ].compact
          end
        end

        def timing
          tag.span(class: "UnmagicAIChatPayload__timing") do
            safe_join [
              Icons.svg(view, :timer),
              tag.span(AIChat.t("payload.took", default: "Took"), class: "UnmagicVisuallyHidden"),
              Duration.format(@duration)
            ]
          end
        end

        # Scrollable, so reachable by keyboard and named for it: a region nobody can
        # scroll without a mouse is a trap in reverse.
        def code(source, language)
          tag.div(Components.configuration.code_block.call(view, source, language),
            class: "UnmagicAIChatPayload__code", tabindex: 0, role: "region",
            "aria-label": @label.presence || AIChat.t("payload.label", default: "Payload"))
        end
      end
    end
  end
end
