# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # A turn that fell over, and what it fell over on. See
      # ActionViewHelpers#ai_chat_failure.
      class Failure
        def initialize(view, live: false, **options)
          @view = view
          @live = live
          @options = options
          @cause = nil
          @details = []
          @retry = nil
        end

        # One line naming the error, above the fold.
        def cause(text)
          @cause = text
          nil
        end

        # A row inside the disclosure, for whoever is working on the assistant.
        def detail(label, payload, language: nil)
          @details << Payload.new(view, payload, label: label, language: language)
          nil
        end

        def retry(content = nil, &block)
          @retry = block ? view.capture(&block) : content
          nil
        end

        # The sentence is always the caller's: the raw exception is for the logs,
        # never for whoever asked. role="alert" only when streamed in, or every past
        # failure in a reloaded transcript would be announced.
        def render(message)
          details = @details.map(&:render).select(&:present?)

          view.content_tag(:div, **@options, role: ("alert" if @live),
            class: view.class_names("UnmagicAIChatFailure", @options[:class])) do
            safe_join [
              tag.div(class: "UnmagicAIChatFailure__head") do
                safe_join [
                  Icons.svg(view, :circle_x, class: "UnmagicAIChatFailure__icon"),
                  tag.div(class: "UnmagicAIChatFailure__text") do
                    safe_join [
                      tag.p(message, class: "UnmagicAIChatFailure__message"),
                      (tag.p(@cause, class: "UnmagicAIChatFailure__cause") if @cause.present?)
                    ].compact
                  end
                ]
              end,
              (disclosure(details) if details.any?),
              (tag.div(@retry, class: "UnmagicAIChatFailure__retry") if @retry.present?)
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def disclosure(details)
          tag.details(class: "UnmagicAIChatFailure__details") do
            safe_join [
              tag.summary(class: "UnmagicAIChatFailure__summary") do
                safe_join [ AIChat.t("failure.details", default: "Details"), Icons.svg(view, :chevron_right, class: "UnmagicAIChatChevron") ]
              end,
              tag.div(safe_join(details), class: "UnmagicAIChatFailure__body")
            ]
          end
        end
      end
    end
  end
end
