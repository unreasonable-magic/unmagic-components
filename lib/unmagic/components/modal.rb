# frozen_string_literal: true

module Unmagic
  module Components
    # The one shared modal a layout mounts: a native <dialog> holding the turbo frame
    # that modal links load into, plus inert templates for the loading and error
    # states the <unmagic-modal> element swaps in. See ActionViewHelpers#modal_frame.
    class Modal
      def initialize(view, id:)
        @view = view
        @id = id
      end

      # overflow stays visible (see the CSS) so a dropdown inside a dialog form isn't
      # clipped; a dialog keeps its content short enough to fit instead.
      def render
        view.content_tag("unmagic-modal") do
          tag.dialog class: "UnmagicDialogBox", data: { unmagic_dialog: "" } do
            safe_join [
              view.turbo_frame_tag(@id),
              tag.template(skeleton, data: { unmagic_modal_skeleton: "" }),
              tag.template(error, data: { unmagic_modal_error: "" })
            ]
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      # Framed like a real dialog, so the panel is sized before the form arrives and
      # nothing jumps when it does.
      def skeleton
        tag.div class: "UnmagicDialog", role: "status" do
          safe_join [
            tag.span(I18n.t("unmagic.components.modal.loading", default: "Loading…"), class: "UnmagicVisuallyHidden"),
            tag.header(bar("title"), class: "UnmagicDialog__header"),
            tag.div(class: "UnmagicDialog__body") do
              safe_join Array.new(3) { tag.div(safe_join([ bar("label"), bar("input") ]), class: "UnmagicDialog__skeleton-field") }
            end,
            tag.div(bar("button"), class: "UnmagicDialog__footer")
          ]
        end
      end

      def bar(kind)
        tag.div class: "UnmagicSkeleton UnmagicDialog__skeleton-#{kind}"
      end

      def error
        panel = Dialog.new(view, title: I18n.t("unmagic.components.modal.error_title", default: "Couldn’t load"),
          role: "alert")

        panel.footer do
          tag.button type: "button", class: Button.classes(:primary), data: { unmagic_modal_retry: "" } do
            safe_join [ Icons.svg(view, :rotate_cw), I18n.t("unmagic.components.modal.retry", default: "Try again") ]
          end
        end

        panel.render(
          tag.div(class: "UnmagicDialog__error") do
            safe_join [
              Icons.svg(view, :circle_x),
              tag.p(I18n.t("unmagic.components.modal.error_message",
                default: "Something went wrong loading this. Check your connection and try again."))
            ]
          end
        )
      end
    end
  end
end
