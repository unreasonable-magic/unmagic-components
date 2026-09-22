# frozen_string_literal: true

module Unmagic
  module Components
    # A client-side crop with a PNG result. See ActionViewHelpers#image_crop.
    class ImageCrop
      def initialize(view, src, alt:, aspect: nil, circular: false, name: nil, **options)
        raise ArgumentError, "image source must not be blank" if src.blank?
        raise ArgumentError, "aspect must be a finite positive number" if aspect && (!aspect.is_a?(Numeric) || !aspect.finite? || aspect <= 0)
        @view, @src, @alt, @aspect, @circular, @name, @options = view, src, alt, circular ? 1 : aspect, circular, name, options
      end

      def render
        @view.content_tag("unmagic-image-crop", **@options, aspect: @aspect, circular: @circular ? "" : nil, class: @view.class_names("UnmagicImageCrop", @options[:class])) do
          @view.safe_join([ stage, controls, @view.tag.img(alt: @alt, hidden: true, data: { crop_preview: true }), (@view.hidden_field_tag(@name, nil, data: { image_result: true }) if @name),
            @view.content_tag(:p, nil, role: "status", data: { image_status: true, error: word(:error, "Could not crop this image. Use an image from this site or one that allows cross-origin access.") }) ].compact)
        end
      end

      private

      def stage
        @view.content_tag(:div, class: "UnmagicImageCrop__stage") do
          @view.safe_join([ @view.image_tag(@src, alt: @alt, crossorigin: "anonymous", draggable: false),
            @view.content_tag(:div, @view.content_tag(:span, nil, data: { crop_handle: true }), class: "UnmagicImageCrop__selection", hidden: true, aria: { hidden: true }) ])
        end
      end

      def controls
        @view.content_tag(:div, class: "UnmagicImageCrop__controls") do
          @view.safe_join(%i[x y width height].map do |key|
            @view.content_tag(:label) do
              @view.safe_join([ word(key, key.to_s.capitalize), @view.tag.input(type: "number", min: 0, step: 1, value: 0, disabled: true, data: { crop_control: key }) ])
            end
          end + [ @view.button_tag(word(:crop, "Crop image"), type: "button", disabled: true, class: "UnmagicButton", data: { crop_apply: true }),
            @view.button_tag(word(:reset, "Reset"), type: "button", disabled: true, class: "UnmagicButton", data: { crop_reset: true }) ])
        end
      end

      def word(key, fallback)
        I18n.t("unmagic.components.image_crop.#{key}", default: fallback)
      end
    end
  end
end
