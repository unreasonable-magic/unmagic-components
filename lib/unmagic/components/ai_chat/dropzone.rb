# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # A region that takes dropped and pasted files. The chip it draws for a
      # pending file is message_attachments' tile. See
      # ActionViewHelpers#ai_chat_dropzone.
      class Dropzone
        def initialize(view, input:, url: nil, field: nil, chips: nil, label: nil, **options)
          raise ArgumentError, "ai_chat_dropzone needs an input: (dragging is never the only way in)" if input.blank?
          raise ArgumentError, "an uploading ai_chat_dropzone needs a field: to post the uploads under" if url && field.blank?

          @view = view
          @input = input
          @url = url
          @field = field
          @chips = chips
          @label = label
          @options = options
        end

        # The overlay can't take the pointer, or it would swallow the drop it
        # advertises; and it's only feedback for a gesture no keyboard can make.
        def render(content)
          label = @label || AIChat.t("attachments.drop", default: "Drop to attach")

          view.content_tag("unmagic-dropzone", **@options,
            input: @input, url: @url, field: @field, chips: @chips,
            data: {
              attached: AIChat.t("attachments.attached", name: "{name}", default: "%{name} attached"),
              failed: AIChat.t("attachments.failed", name: "{name}", default: "Couldn't attach %{name}"),
              remove: AIChat.t("attachments.remove", name: "{name}", default: "Remove %{name}")
            }.merge(@options[:data] || {}),
            class: view.class_names("UnmagicAIChatDropzone", @options[:class])) do
            safe_join [
              tag.div(tag.p(safe_join([ Icons.svg(view, :paperclip), label ])),
                class: "UnmagicAIChatDropzone__overlay", "aria-hidden": "true"),
              content,
              tag.span(class: "UnmagicVisuallyHidden", "aria-live": "polite", "data-dropzone-status": ""),
              chip
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # What an attached file looks like before it's sent. The element clones it,
        # so the chip is the server's markup rather than HTML built in script.
        def chip
          tag.template("data-dropzone-chip": "") do
            tag.div(class: "UnmagicMessageAttachments__file") do
              safe_join [
                Icons.svg(view, :file, class: "UnmagicMessageAttachments__glyph"),
                tag.span(class: "UnmagicMessageAttachments__name", "data-dropzone-name": ""),
                tag.span(class: "UnmagicMessageAttachments__size", "data-dropzone-size": ""),
                tag.button(Icons.svg(view, :x), type: "button", class: "UnmagicMessageAttachments__remove",
                  "data-dropzone-remove": "")
              ]
            end
          end
        end
      end
    end
  end
end
