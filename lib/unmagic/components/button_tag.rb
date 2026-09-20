# frozen_string_literal: true

module Unmagic
  module Components
    # A button, a link that looks like one, or a button_to form, from one call.
    # See ActionViewHelpers#button.
    class ButtonTag
      def initialize(view, label, variant: :default, size: nil, icon: nil, href: nil, method: nil, loading: false,
        disabled: false, block: false, type: "button", **options)
        @view = view
        @label = label
        @variant = variant
        @size = size
        @icon = icon
        @href = href
        @method = method
        @loading = loading
        @disabled = disabled
        @block = block
        @type = type
        @options = options
        Button.classes(variant, size: size)
      end

      def render
        if @href && @method && @method.to_s.downcase != "get"
          form
        elsif @href
          link
        else
          button
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def classes
        view.class_names(Button.classes(@variant, size: @size), { "UnmagicButton--block" => @block }, @options[:class])
      end

      # An icon-only button keeps its label for a screen reader and a hover.
      def icon_only? = @variant == :icon

      def attributes
        attributes = @options.merge(class: classes)
        attributes[:"aria-busy"] = "true" if @loading
        attributes.merge!("aria-label": @label, title: @label) if icon_only?
        attributes
      end

      def content
        safe_join [ glyph, (tag.span(@label, class: "UnmagicButton__label") unless icon_only?) ].compact
      end

      # While loading, a spinner takes the icon's place (or leads the label), so
      # the button says it is busy without changing width much.
      def glyph
        if @loading
          Spinner.new(view, size: :small, label: false, class: "UnmagicButton__icon").render
        else
          case @icon
          when nil then nil
          when Symbol then Icons.svg(view, @icon, class: "UnmagicButton__icon")
          else @icon
          end
        end
      end

      def button
        tag.button(content, type: @type, disabled: (@disabled || @loading) || nil, **attributes)
      end

      # A link can't be disabled, so it is marked and taken out of the tab order.
      def link
        extra = @disabled || @loading ? { "aria-disabled": "true", tabindex: -1 } : {}
        view.link_to(content, @href, **attributes, **extra)
      end

      def form
        view.button_to(@href, method: @method, disabled: (@disabled || @loading) || nil, **attributes,
          form_class: "UnmagicButton__form") { content }
      end
    end
  end
end
