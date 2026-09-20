# frozen_string_literal: true

module Unmagic
  module Components
    # A password input with a button that shows what was typed. See
    # FormBuilder#password_field and ActionViewHelpers#password_field_tag.
    module Password
      # Wraps a rendered password input in <unmagic-password> with its toggle. The
      # button renders hidden and the element reveals it on upgrade, so without
      # script there is a working password field and no dead button.
      def self.wrap(view, input, id:)
        label = I18n.t("unmagic.components.password.show", default: "Show password")

        view.content_tag("unmagic-password", class: "UnmagicPassword") do
          view.safe_join [
            input,
            view.tag.button(type: "button", class: "UnmagicButton UnmagicButton--icon UnmagicPassword__toggle",
              "aria-controls": id, "aria-pressed": "false", "aria-label": label, title: label, hidden: true) do
              view.safe_join [
                Icons.svg(view, :eye, class: "UnmagicPassword__show"),
                Icons.svg(view, :eye_off, class: "UnmagicPassword__hide")
              ]
            end
          ]
        end
      end
    end
  end
end
