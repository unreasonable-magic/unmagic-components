# frozen_string_literal: true

module Unmagic
  module Components
    # A choice of one (or several) drawn as a run of joined toggles: a segmented
    # control. See ActionViewHelpers#toggle_group.
    class ToggleGroup
      def initialize(view, name:, value: nil, multiple: false, label: nil, size: nil, **options)
        @view = view
        @name = name
        @value = multiple ? Array(value).map(&:to_s) : value&.to_s
        @multiple = multiple
        @label = label
        @size = size
        @options = options
        @items = []
      end

      # A choice: its label, its value, and an icon: before the label.
      def option(label, value, icon: nil, disabled: false, **options)
        @items << { label: label, value: value.to_s, icon: icon, disabled: disabled, options: options }
        nil
      end

      # Native radios (or checkboxes) drawn as buttons: a form submits the choice,
      # the arrow keys move it, and no script is needed. Each is a label around
      # its input, so the whole face is the target.
      def render
        return "".html_safe if @items.empty?

        classes = view.class_names("UnmagicToggleGroup", { "UnmagicToggleGroup--#{@size}" => @size }, @options[:class])

        tag.div(**@options, role: (@multiple ? "group" : "radiogroup"), "aria-label": @label, class: classes) do
          safe_join(@items.map { |item| choice(item) })
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def checked?(item) = @multiple ? @value.include?(item[:value]) : @value == item[:value]

      def choice(item)
        tag.label(class: view.class_names("UnmagicToggle UnmagicToggle--input", item[:options][:class])) do
          safe_join [
            tag.input(type: @multiple ? "checkbox" : "radio", name: @multiple ? "#{@name}[]" : @name, value: item[:value],
              checked: checked?(item) || nil, disabled: item[:disabled] || nil, class: "UnmagicToggle__input",
              **item[:options].except(:class)),
            tag.span(class: "UnmagicToggle__face") do
              safe_join [
                (item[:icon].is_a?(Symbol) ? Icons.svg(view, item[:icon], class: "UnmagicToggle__icon") : item[:icon]),
                tag.span(item[:label], class: "UnmagicToggle__label")
              ].compact
            end
          ]
        end
      end
    end
  end
end
