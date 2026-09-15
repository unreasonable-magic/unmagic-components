# frozen_string_literal: true

module Unmagic
  module Components
    # The markup the confirm element clones for each data-turbo-confirm prompt,
    # rendered on the server so its words go through I18n. Without it on the page the
    # element falls back to the same markup in English. See
    # ActionViewHelpers#confirm_dialog_template.
    class ConfirmTemplate
      def initialize(view)
        @view = view
      end

      def render
        tag.template data: { unmagic_confirm: "" } do
          tag.dialog class: "UnmagicDialogBox", role: "alertdialog", data: { unmagic_dialog: "" } do
            tag.form method: "dialog", class: "UnmagicDialog" do
              safe_join [
                tag.header(class: "UnmagicDialog__header") do
                  tag.h2(t(:title, "Are you sure?"), class: "UnmagicDialog__title", data: { unmagic_confirm_title: "" })
                end,
                tag.div(class: "UnmagicDialog__body") { tag.p(data: { unmagic_confirm_message: "" }) },
                tag.div(class: "UnmagicDialog__footer") do
                  safe_join [
                    tag.button(t(:cancel, "Cancel"), value: "cancel", class: Button.classes,
                      data: { unmagic_confirm_cancel: "" }),
                    tag.button(t(:accept, "Confirm"), value: "confirm", class: Button.classes(:primary),
                      data: { unmagic_confirm_accept: "" })
                  ]
                end
              ]
            end
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def t(key, default) = I18n.t("unmagic.components.confirm.#{key}", default: default)
    end
  end
end
