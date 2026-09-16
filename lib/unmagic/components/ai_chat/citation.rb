# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # A quotation of a record the application holds, rendered from the record
      # rather than from the model's paraphrase of it. See
      # ActionViewHelpers#ai_chat_citation.
      class Citation
        def initialize(view, compact: false, **options)
          @view = view
          @compact = compact
          @options = options
          @avatar = nil
          @who = nil
          @when = nil
          @quote = nil
        end

        # With no block, the gem's own avatar for whoever who: names, hidden from
        # assistive technology since the name is read beside it.
        def avatar(content = nil, src: nil, &block)
          @avatar = block ? view.capture(&block) : (content || { src: src })
          nil
        end

        def who(text)
          @who = text
          nil
        end

        def when(time, url: nil)
          @when = [ time, url ]
          nil
        end

        # Plain text, escaped, newlines kept. The quoted record can't inject markup
        # through it, and neither can the model that chose to quote it.
        def quote(text)
          @quote = text.to_s
          nil
        end

        def render
          return "".html_safe if [ @who, @when, @quote ].all?(&:blank?)

          view.content_tag(:figure, **@options,
            class: view.class_names("UnmagicAIChatCitation", "not-prose",
              { "UnmagicAIChatCitation--compact" => @compact }, @options[:class])) do
            safe_join [
              (tag.div(avatar_markup, class: "UnmagicAIChatCitation__avatar") if @avatar && !@compact),
              tag.div(class: "UnmagicAIChatCitation__main") do
                safe_join [ caption, (tag.blockquote(@quote, cite: @when&.last, class: "UnmagicAIChatCitation__quote") if @quote.present?) ].compact
              end
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def avatar_markup
          return @avatar unless @avatar.is_a?(Hash)

          Avatar.new(view, @who, src: @avatar[:src], size: :small, "aria-hidden": "true").render
        end

        def caption
          return if @who.blank? && @when.nil?

          tag.figcaption(class: "UnmagicAIChatCitation__caption") do
            safe_join [ (tag.span(@who, class: "UnmagicAIChatCitation__who") if @who.present?), timestamp ].compact
          end
        end

        def timestamp
          return unless @when

          time, url = @when
          stamp = view.local_time_tag(time)
          url ? view.link_to(stamp, url, class: "UnmagicAIChatCitation__when") : tag.span(stamp, class: "UnmagicAIChatCitation__when")
        end
      end
    end
  end
end
