# frozen_string_literal: true

module Unmagic
  module Components
    module Messaging
      # The files that came with a message, as tiles. The drop zone that takes
      # them before they're sent (AIChat::Dropzone) draws the same tile. See
      # ActionViewHelpers#message_attachments.
      class Attachments
        ALIGNMENTS = %i[start end].freeze

        File = Struct.new(:name, :size, :url, :thumbnail)

        def initialize(view, align: :start, **options)
          Messaging.validate!("message_attachments", :align, align, ALIGNMENTS)

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
            class: view.class_names("UnmagicMessageAttachments", "UnmagicMessageAttachments--#{@align}", @options[:class])) do
            safe_join(@files.map { |file| item(file) })
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # A thumbnail is decoration: the name beside it is the name.
        def item(file)
          content = safe_join [
            (file.thumbnail ? tag.img(src: file.thumbnail, alt: "", class: "UnmagicMessageAttachments__thumb") : Icons.svg(view, :file, class: "UnmagicMessageAttachments__glyph")),
            tag.span(file.name, class: "UnmagicMessageAttachments__name"),
            (tag.span(view.number_to_human_size(file.size), class: "UnmagicMessageAttachments__size") if file.size)
          ].compact

          tag.li(class: "UnmagicMessageAttachments__file") do
            file.url ? view.link_to(content, file.url, class: "UnmagicMessageAttachments__link") : content
          end
        end
      end
    end
  end
end
