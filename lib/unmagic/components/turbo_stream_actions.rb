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
      # tone: :good (default), :warn, :bad, :info, :neutral, :accent or :inverted. Needs flash_toasts on the page.
      # duration: overrides the mount in milliseconds; 0 waits for manual dismissal.
      # position: :top_start, :top, :top_end, :bottom_start, :bottom, :bottom_end.
      # width: :short (384px), :long (560px), or a positive pixel integer.
      # title: adds a heading; icon: chooses a bundled icon, false hides it.
      # close_button: true by default; false hides only the built-in close button.
      # For duration: 0, provide a dismiss action when hiding the close button.
      # layout: :horizontal (default) or :vertical places actions below the message.
      # target: selects a flash_toasts mount. Other options go on the toast root.
      # A block yields a builder with leading, actions and body capture slots.
      def toast(message = nil, tone: :good, target: Toast::TARGET, **options, &block)
        builder = Toast.new(@view_context, message, tone: tone, **options)
        @view_context.capture(builder, &block) if block
        append target, builder.template
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
