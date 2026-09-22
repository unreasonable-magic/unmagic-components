# frozen_string_literal: true

module Unmagic
  module Components
    # An image opened in a native modal. See ActionViewHelpers#image_zoom.
    class ImageZoom
      def initialize(view, src, alt:, zoom_src: nil, **options)
        raise ArgumentError, "image source must not be blank" if src.blank?
        @view, @src, @alt, @zoom_src, @options = view, src, alt, zoom_src || src, options
      end

      def render
        label = I18n.t("unmagic.components.image_zoom.open", default: "Zoom image")
        close = I18n.t("unmagic.components.image_zoom.close", default: "Close image")
        @view.content_tag("unmagic-image-zoom", **@options, class: @view.class_names("UnmagicImageZoom", @options[:class])) do
          @view.safe_join([
            @view.content_tag(:button, @view.image_tag(@src, alt: @alt), type: "button", class: "UnmagicImageZoom__trigger", aria: { label: label, haspopup: "dialog" }),
            @view.content_tag(:dialog, class: "UnmagicImageZoom__dialog", aria: { label: @alt.presence || label }) do
              @view.safe_join([
                @view.button_tag(close, type: "button", class: "UnmagicButton UnmagicImageZoom__close", data: { image_close: true }),
                @view.image_tag(@zoom_src, alt: @alt)
              ])
            end
          ])
        end
      end
    end
  end
end
