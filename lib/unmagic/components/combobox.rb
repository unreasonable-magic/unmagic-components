# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A text input that filters a list of options, choosing one or several, with
    # the list served from a collection or fetched as you type. See
    # ActionViewHelpers#combobox_tag, FormBuilder#combobox and #combobox_results.
    class Combobox
      def initialize(view, name, collection: [], value: :id, text: :to_s, multiple: false, selected: nil, src: nil,
        min_length: 1, debounce: 200, placeholder: nil, create: false, id: nil, input: {}, label: nil, **options)
        @view = view
        @name = name
        @collection = collection
        @value_method = value
        @text_method = text
        @multiple = multiple
        @selected = Array(selected).map(&:to_s)
        @src = src
        @min_length = min_length
        @debounce = debounce
        @placeholder = placeholder
        @create = create
        @base = (id || name.to_s.gsub(/[^a-z0-9_]+/i, "_")).to_s.delete_suffix("_combobox")
        @id = "#{@base}_combobox"
        @input = input
        @label = label
        @options = options
        @entries = []
      end

      # One option, recorded by the block or from value: and text:.
      def option(value, label:, keywords: nil, disabled: false, &block)
        @entries << { value: value.to_s, label: label, keywords: keywords, disabled: disabled, content: block ? view.capture(&block) : nil }
        nil
      end

      def group(label, &block)
        @entries << { group: label }
        view.capture(self, &block)
        @entries << { group_end: true }
        nil
      end

      # The block is called once per record; with no collection it is called once
      # with nil, to record options and groups by hand.
      def build(&block)
        if block && @collection.blank?
          block.call(self, nil)
        else
          @collection.each do |record|
            if block
              block.call(self, record)
            else
              option(call(record, @value_method), label: call(record, @text_method))
            end
          end
        end
        self
      end

      def render
        chosen = @entries.reject { |e| e[:group] || e[:group_end] }.select { |e| @selected.include?(e[:value]) }

        view.content_tag("unmagic-combobox", **@options, id: @id, multiple: (@multiple ? "" : nil), src: @src,
          "min-length": (@min_length if @src), debounce: (@debounce if @src), create: (@create.presence || nil),
          class: view.class_names("UnmagicCombobox", @options[:class])) do
          safe_join [
            control(chosen),
            (tag.input(type: "hidden", name: "#{@name}[]", value: "", data: { unmagic_combobox_blank: "" }) if @multiple),
            (tag.input(type: "hidden", name: @name, value: chosen.first&.dig(:value), data: { unmagic_combobox_value: "" }) unless @multiple),
            popup
          ].compact
        end
      end

      # The options alone, for a remote search's response.
      def results
        frame = view.respond_to?(:turbo_frame_request_id) ? view.turbo_frame_request_id : nil
        list = listbox_items(base: frame&.delete_suffix("_results") || @id)
        frame ? view.turbo_frame_tag(frame) { list } : list
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def call(record, method) = method.respond_to?(:call) ? method.call(record) : record.public_send(method)

      def listbox_id = "#{@id}_listbox"

      def control(chosen)
        tag.div(class: "UnmagicCombobox__control") do
          safe_join [
            (chips(chosen) if @multiple),
            tag.input(**@input, type: "text", id: @input[:id] || @base,
              class: view.class_names("UnmagicCombobox__input", @input[:class]), role: "combobox", "aria-expanded": "false",
              "aria-autocomplete": "list", "aria-controls": listbox_id, autocomplete: "off", spellcheck: "false",
              placeholder: @placeholder, value: (@multiple ? nil : chosen.first&.dig(:label)))
          ].compact
        end
      end

      def chips(chosen)
        tag.ul(class: "UnmagicCombobox__chips", "aria-label": I18n.t("unmagic.components.combobox.selected", default: "Selected")) do
          safe_join(chosen.map { |entry| chip(entry) })
        end
      end

      def chip(entry)
        tag.li(class: "UnmagicCombobox__chip", data: { value: entry[:value] }) do
          safe_join [
            tag.span(entry[:label], class: "UnmagicCombobox__chip-label"),
            tag.button(Icons.svg(view, :x), type: "button", class: "UnmagicCombobox__remove",
              "aria-label": I18n.t("unmagic.components.combobox.remove", label: entry[:label], default: "Remove %{label}")),
            tag.input(type: "hidden", name: "#{@name}[]", value: entry[:value])
          ]
        end
      end

      def popup
        tag.div(class: "UnmagicCombobox__popup", popover: "manual") do
          safe_join [
            tag.div(role: "listbox", id: listbox_id, class: "UnmagicCombobox__listbox",
              "aria-multiselectable": (@multiple ? "true" : nil), "aria-label": @label || @placeholder) do
              safe_join [
                listbox_items(base: @id),
                (view.turbo_frame_tag("#{@id}_results") if @src && view.respond_to?(:turbo_frame_tag)),
                tag.div(I18n.t("unmagic.components.combobox.empty", default: "No matches"), class: "UnmagicCombobox__message", data: { unmagic_combobox_empty: "" }, hidden: true),
                (tag.div(I18n.t("unmagic.components.combobox.searching", default: "Searching…"), class: "UnmagicCombobox__message", data: { unmagic_combobox_searching: "" }, hidden: true) if @src)
              ].compact
            end,
            tag.p(class: "UnmagicCombobox__status UnmagicVisuallyHidden", role: "status")
          ]
        end
      end

      def listbox_items(base:)
        index = -1
        depth = 0
        safe_join(@entries.map do |entry|
          if entry[:group]
            depth += 1
            group_id = "#{base}_group_#{index + 1}"
            "<div role=\"group\" class=\"UnmagicCombobox__group\" aria-labelledby=\"#{group_id}\"><div class=\"UnmagicCombobox__group-label\" id=\"#{group_id}\">#{ERB::Util.html_escape(entry[:group])}</div>".html_safe
          elsif entry[:group_end]
            "</div>".html_safe
          else
            index += 1
            selected = @selected.include?(entry[:value])
            tag.div(role: "option", id: "#{base}_option_#{index}", class: "UnmagicCombobox__option",
              data: { value: entry[:value], label: entry[:label], keywords: entry[:keywords] }.compact,
              "aria-selected": selected.to_s, "aria-disabled": (entry[:disabled] ? "true" : nil)) do
              safe_join [ (entry[:content] || entry[:label]), Icons.svg(view, :check, class: "UnmagicCombobox__check") ]
            end
          end
        end)
      end
    end
  end
end
