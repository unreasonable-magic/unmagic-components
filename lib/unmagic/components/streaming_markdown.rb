# frozen_string_literal: true

module Unmagic
  module Components
    # Server-rendered HTML, revealed at a steady pace as later renders of it are
    # streamed in. See ActionViewHelpers#streaming_markdown_tag.
    class StreamingMarkdown
      def initialize(view, id:, final: false, streaming: false, **options)
        raise ArgumentError, "streaming_markdown_tag needs an id: to stream into" if id.blank?

        @view = view
        @id = id
        @final = final
        @streaming = streaming
        @options = options
      end

      # aria-busy only while the caller says a reply is live. It is what stops a
      # transcript's live region announcing every flush, and a settled reply
      # rendered busy would be skipped by a screen reader if the script never ran.
      def render(content)
        view.content_tag("unmagic-streaming-markdown", content, **@options,
          id: @id,
          final: ("" if @final),
          "aria-busy": ("true" if @streaming && !@final),
          class: view.class_names("UnmagicStreamingMarkdown", @options[:class]))
      end

      private

      attr_reader :view
    end
  end
end
