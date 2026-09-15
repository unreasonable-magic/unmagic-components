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
    end
  end
end
