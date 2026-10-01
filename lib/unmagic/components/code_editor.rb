# frozen_string_literal: true

module Unmagic
  module Components
    # Enhances a native textarea only when an editor is present on the page.
    module CodeEditor
      LANGUAGES = %i[plaintext json graphql javascript typescript python ruby html css sql java cpp go].freeze

      def self.wrap(view, textarea, language: :plaintext, schema: nil)
        unless LANGUAGES.include?(language)
          raise ArgumentError, "unknown code editor language #{language.inspect} (expected one of #{LANGUAGES.inspect})"
        end

        view.content_tag("unmagic-code-editor", class: "UnmagicCodeEditor", language: language, schema: schema) do
          view.safe_join [
            textarea,
            view.tag.div("data-editor-mount": true),
            view.tag.span(class: "UnmagicVisuallyHidden", role: "status", "data-editor-status": true,
              "data-error-message": I18n.t("unmagic.components.code_editor.error", default: "Editor unavailable. Use the text field."))
          ]
        end
      end
    end
  end
end
