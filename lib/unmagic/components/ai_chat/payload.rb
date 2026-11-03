# frozen_string_literal: true

require "json"

module Unmagic
  module Components
    module AIChat
      # What went into a tool call or came back out of it, to be read exactly as it
      # was written. A child of a tool call's fold or a failure's: a <figure> with
      # a caption and a scrollable block, styled by the parent that holds it. See
      # ActionViewHelpers#ai_chat_payload.
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

          tag.figure(**@options) do
            safe_join [ caption(source), region(source, language) ].compact
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

        def caption(source)
          return if @label.blank? && @duration.nil? && !@copy

          tag.figcaption do
            safe_join [ @label, (timing if @duration), (view.copy_button(source) if @copy) ].compact
          end
        end

        # How long the tool took, as a <time> whose datetime is the duration itself.
        def timing
          tag.time(datetime: format("PT%gS", @duration.to_f)) do
            safe_join [
              Icons.svg(view, :timer),
              tag.span(AIChat.t("payload.took", default: "Took"), class: "UnmagicVisuallyHidden"),
              Duration.format(@duration)
            ]
          end
        end

        # Scrollable, so reachable by keyboard and named for it: a region nobody can
        # scroll without a mouse is a trap in reverse.
        def region(source, language)
          tag.div(Components.configuration.code_block.call(view, source, language),
            tabindex: 0, role: "region", "aria-label": @label.presence || AIChat.t("payload.label", default: "Payload"))
        end
      end
    end
  end
end
