# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # Files attached to a turn: the tiles a sent turn carries. The drop zone that
      # takes them is Dropzone. See ActionViewHelpers#ai_chat_attachments.
      class Attachments
        ALIGNMENTS = %i[start end].freeze

        File = Struct.new(:name, :size, :url, :thumbnail)

        def initialize(view, align: :start, **options)
          AIChat.validate!("ai_chat_attachments", :align, align, ALIGNMENTS)

          @view = view
          @align = align
          @options = options
          @files = []
        end

        def file(name, size: nil, url: nil, thumbnail: nil)
          @files << File.new(name.to_s, size, url, thumbnail)
          nil
        end

        def render
          return "".html_safe if @files.empty?

          view.content_tag(:ul, **@options,
            class: view.class_names("UnmagicAIChatAttachments", "UnmagicAIChatAttachments--#{@align}", @options[:class])) do
            safe_join(@files.map { |file| item(file) })
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # A thumbnail is decoration: the name beside it is the name.
        def item(file)
          content = safe_join [
            (file.thumbnail ? tag.img(src: file.thumbnail, alt: "", class: "UnmagicAIChatAttachments__thumb") : Icons.svg(view, :file, class: "UnmagicAIChatAttachments__glyph")),
            tag.span(file.name, class: "UnmagicAIChatAttachments__name"),
            (tag.span(view.number_to_human_size(file.size), class: "UnmagicAIChatAttachments__size") if file.size)
          ].compact

          tag.li(class: "UnmagicAIChatAttachments__file") do
            file.url ? view.link_to(content, file.url, class: "UnmagicAIChatAttachments__link") : content
          end
        end
      end

      # A region that takes dropped and pasted files. See
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
            tag.div(class: "UnmagicAIChatAttachments__file") do
              safe_join [
                Icons.svg(view, :file, class: "UnmagicAIChatAttachments__glyph"),
                tag.span(class: "UnmagicAIChatAttachments__name", "data-dropzone-name": ""),
                tag.span(class: "UnmagicAIChatAttachments__size", "data-dropzone-size": ""),
                tag.button(Icons.svg(view, :x), type: "button", class: "UnmagicAIChatAttachments__remove",
                  "data-dropzone-remove": "")
              ]
            end
          end
        end
      end
    end
  end
end
