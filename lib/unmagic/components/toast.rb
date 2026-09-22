# frozen_string_literal: true

module Unmagic
  module Components
    # Server-rendered toast content, delivered as an inert template to a Toasts mount.
    class Toast
      TONES = %i[good warn bad info neutral accent inverted].freeze
      POSITIONS = %i[top_start top top_end bottom_start bottom bottom_end].freeze
      LAYOUTS = %i[horizontal vertical].freeze
      WIDTHS = { short: 384, long: 560 }.freeze
      TARGET = "unmagic_toasts"

      def initialize(view, message = nil, tone: :good, title: nil, icon: nil, duration: nil,
        position: nil, width: :short, layout: :horizontal, close_button: true, **options)
        self.class.validate(:tone, tone, TONES)
        self.class.validate(:position, position, POSITIONS) unless position.nil?
        self.class.validate(:layout, layout, LAYOUTS)
        self.class.validate_duration(duration) unless duration.nil?
        unless WIDTHS.key?(width) || (width.is_a?(Integer) && width.positive?)
          raise ArgumentError, "toast width must be :short, :long, or a positive pixel integer"
        end

        @close_button = close_button
        @view, @message, @tone, @title, @icon = view, message, tone, title, icon
        @duration, @position, @width, @layout, @options = duration, position, WIDTHS.fetch(width, width), layout, options
      end

      def self.validate(option, value, values)
        raise ArgumentError, "unknown toast #{option} #{value.inspect} (expected one of #{values.inspect})" unless values.include?(value)
      end

      def self.validate_duration(value)
        unless value.is_a?(Numeric) && value.finite? && value >= 0
          raise ArgumentError, "toast duration must be a finite nonnegative number of milliseconds"
        end
      end

      # Captured slots return nil, like the other component builders.
      def leading(&block)
        @leading = view.capture(&block)
        nil
      end

      def actions(&block)
        @actions = view.capture(&block)
        nil
      end

      def body(&block)
        @body = view.capture(&block)
        nil
      end

      def template
        tag.template(render, data: { unmagic_toast_template: "" })
      end

      def render
        data = (@options[:data] || {}).merge(unmagic_toast: "", duration: @duration,
          position: @position, layout: (@layout unless @layout == :horizontal))
        tag.div(**@options, class: view.class_names("UnmagicToast", "UnmagicToast--#{@tone}", @options[:class]),
          role: (@tone == :bad ? "alert" : @options[:role]), data: data,
          style: "--unmagic-toast-width: #{@width}px; #{@options[:style]}") do
          safe_join [
            leading_content,
            tag.div(class: "UnmagicToast__main") do
              safe_join [
                tag.div(class: "UnmagicToast__content") do
                  @body || safe_join([
                    (@title.nil? ? nil : tag.div(@title, class: "UnmagicToast__title")),
                    tag.div(@message, class: "UnmagicToast__message")
                  ].compact)
                end,
                (@actions && tag.div(@actions, class: "UnmagicToast__actions"))
              ].compact
            end,
            (tag.button(Icons.svg(view, :x), type: "button", class: "UnmagicToast__dismiss",
              "aria-label": I18n.t("unmagic.components.toast.dismiss", default: "Dismiss"),
              data: { unmagic_toast_dismiss: "" }) if @close_button)
          ].compact
        end
      end

      private

      attr_reader :view
      delegate :tag, :safe_join, to: :view, private: true

      def leading_content
        return Icons.svg(view, @icon, class: "UnmagicToast__icon") if @icon
        return tag.div(@leading, class: "UnmagicToast__leading") if @leading
        return if @icon == false

        Icons.svg(view, Icons::TONE_ICONS.fetch(@tone, :info), class: "UnmagicToast__icon")
      end
    end
  end
end
