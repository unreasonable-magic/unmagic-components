# frozen_string_literal: true

module Unmagic
  module Components
    # A button that is on or off. See ActionViewHelpers#toggle.
    class Toggle
      def initialize(view, label, pressed: false, icon: nil, name: nil, value: "1", size: nil, disabled: false, **options)
        @view = view
        @label = label
        @pressed = pressed
        @icon = icon
        @name = name
        @value = value
        @size = size
        @disabled = disabled
        @options = options
      end

      # With a name: it is a checkbox drawn as a button, so a form submits it and
      # no script is needed. Without one it is a button with aria-pressed, which
      # toggle.js flips.
      def render
        @name ? checkbox : button
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def classes(extra = nil)
        view.class_names("UnmagicToggle", { "UnmagicToggle--icon" => icon_only?, "UnmagicToggle--#{@size}" => @size }, extra, @options[:class])
      end

      def icon_only? = @options.delete(:icon_only) || false

      def content
        safe_join [ glyph, tag.span(@label, class: view.class_names("UnmagicToggle__label", "UnmagicVisuallyHidden" => @hide_label)) ].compact
      end

      def glyph
        case @icon
        when nil then nil
        when Symbol then Icons.svg(view, @icon, class: "UnmagicToggle__icon")
        else @icon
        end
      end

      def button
        tag.button(content, type: "button", "aria-pressed": @pressed.to_s, disabled: @disabled || nil, **@options, class: classes)
      end

      def checkbox
        tag.label(class: classes("UnmagicToggle--input")) do
          safe_join [
            tag.input(type: "checkbox", name: @name, value: @value, checked: @pressed || nil, disabled: @disabled || nil,
              class: "UnmagicToggle__input", **@options.except(:class)),
            tag.span(content, class: "UnmagicToggle__face")
          ]
        end
      end
    end
  end
end
