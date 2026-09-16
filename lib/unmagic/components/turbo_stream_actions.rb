# frozen_string_literal: true

module Unmagic
  module Components
    # Mixed into turbo-rails' stream tag builder by the engine.
    module TurboStreamActions
      # Pops a toast from a stream response — for something that happened outside
      # the flash cycle, where there is no redirect or render to carry a flash.
      #
      #   render turbo_stream: turbo_stream.toast("Invitation sent.")
      #   render turbo_stream: turbo_stream.toast("Couldn't reach Slack.", tone: :bad)
      #
      # tone: :good (default), :warn, :bad or :info. Needs flash_toasts on the page.
      def toast(message, tone: :good)
        append Toast::TARGET, Toast.new(@view_context, message, tone: tone).template
      end

      # Hands the whole of a reply rendered so far to the <unmagic-streaming-markdown>
      # with that id, which paces its way toward it. Send the full render every
      # time, not the new part: the element works out what is new.
      #
      #   turbo_stream.stream_markdown "message_1_content", Markdown.render(message.content)
      #
      # From a model, the same action through Turbo::Broadcastable:
      #
      #   broadcast_action_to chat, action: :stream_markdown, target: "#{dom_id(self)}_content",
      #     html: Markdown.render(content)
      #
      # Needs import "unmagic/components/streaming_markdown".
      def stream_markdown(target, content = nil, **rendering, &block)
        action :stream_markdown, target, content, **rendering, &block
      end
    end
  end
end
