# frozen_string_literal: true

module Unmagic
  module Components
    # The mount point for toasts: the <unmagic-toasts> element, its stack, and a
    # template for each of the request's flashes. See ActionViewHelpers#flash_toasts.
    class Toasts
      def initialize(view, flashes, duration:)
        @view = view
        @flashes = flashes
        @duration = duration
      end

      # The stack is data-turbo-permanent, so a toast on screen — and its dismiss
      # timer — survives a Drive visit or a morph refresh. It is a manual popover
      # so the element can lift it into the top layer, above an open dialog.
      def render
        view.content_tag("unmagic-toasts", id: Toast::TARGET, duration: @duration) do
          safe_join [
            tag.div(class: "UnmagicToasts__stack", id: "#{Toast::TARGET}_stack", popover: "manual",
              "aria-live": "polite", data: { turbo_permanent: "" }),
            *templates
          ]
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def templates
        tones = Components.configuration.flash_tones

        @flashes.each_with_object([]) do |(type, messages), templates|
          tone = tones.fetch(type.to_s, :info)

          Array(messages).each do |message|
            templates << Toast.new(view, message, tone: tone).template if message.present?
          end
        end
      end
    end
  end
end
