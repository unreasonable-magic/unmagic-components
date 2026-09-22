# frozen_string_literal: true

module Unmagic
  module Components
    # Sample an image into an existing field. See ActionViewHelpers#image_color_picker.
    class ImageColorPicker
      def initialize(view, src, alt:, input:, **options)
        raise ArgumentError, "image source must not be blank" if src.blank?
        raise ArgumentError, "input must be a field id" if input.blank?
        @view, @src, @alt, @input, @options = view, src, alt, input, options
      end

      def render
        label = I18n.t("unmagic.components.image_color_picker.pick", default: "Pick a color: use arrow keys to move, Enter to select")
        error = I18n.t("unmagic.components.image_color_picker.error", default: "Could not sample this image. Check the target field and image cross-origin permissions.")
        @view.content_tag("unmagic-image-color-picker", **@options, input: @input, class: @view.class_names("UnmagicImageColorPicker", @options[:class])) do
          @view.safe_join([
            @view.content_tag(:button, type: "button", class: "UnmagicImageColorPicker__surface", aria: { label: label }) do
              @view.safe_join([ @view.image_tag(@src, alt: @alt, crossorigin: "anonymous", draggable: false), @view.tag.span(class: "UnmagicImageColorPicker__cursor", aria: { hidden: true }) ])
            end,
            @view.content_tag(:output, nil, role: "status", data: { image_status: true, error: error })
          ])
        end
      end
    end
  end
end
