# frozen_string_literal: true

ComponentsPreview::Catalog.component :confirm,
  name: "Confirm",
  helper: nil,
  import: "unmagic/components/confirm",
  description: "A dialog in place of window.confirm for data-turbo-confirm. data-turbo-confirm-title, -accept " \
               "and -variant=\"danger\" customise it, and confirm_dialog_template carries its words through I18n.",
  examples: [
    { key: :danger, title: "Danger",
      description: "A custom accept label and the danger variant, for an action that destroys something." },
    { key: :plain, title: "Plain",
      description: "Only data-turbo-confirm, so the dialog uses its default title and buttons." }
  ]
