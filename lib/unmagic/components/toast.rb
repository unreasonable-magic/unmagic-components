# frozen_string_literal: true

module Unmagic
  module Components
    # One toast, and the inert <template> the <unmagic-toasts> element pops it from.
    # A toast arrives as a template rather than as the toast itself so a morph or a
    # stream can deliver it without it rendering in place; the element clones it
    # into the stack. See ActionViewHelpers#flash_toasts.
    class Toast
      TONES = %i[good warn bad info].freeze

      # The <unmagic-toasts> element's id, which a stream appends templates to.
      TARGET = "unmagic_toasts"

      def initialize(view, message, tone:)
        unless TONES.include?(tone)
          raise ArgumentError, "unknown toast tone #{tone.inspect} (expected one of #{TONES.inspect})"
        end

        @view = view
        @message = message
        @tone = tone
      end

      def template
        tag.template(render, data: { unmagic_toast_template: "" })
      end

      # A bad toast interrupts (role="alert"); the rest are announced politely by
      # the stack's own live region.
      def render
        tag.div class: "UnmagicToast UnmagicToast--#{@tone}", role: ("alert" if @tone == :bad),
          data: { unmagic_toast: "" } do
          safe_join [
            Icons.svg(view, Icons::TONE_ICONS.fetch(@tone), class: "UnmagicToast__icon"),
            tag.div(@message, class: "UnmagicToast__message"),
            tag.button(
              Icons.svg(view, :x),
              type: "button", class: "UnmagicToast__dismiss",
              "aria-label": I18n.t("unmagic.components.toast.dismiss", default: "Dismiss"),
              data: { unmagic_toast_dismiss: "" }
            )
          ]
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
