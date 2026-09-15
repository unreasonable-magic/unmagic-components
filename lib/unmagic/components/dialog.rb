# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # The panel chrome inside a dialog: a titled header with a close button, the
    # body, and an optional footer of actions. Shared by the frame modal (`dialog`),
    # the same-page dialog (`dialog_tag`), and the modal's own loading and error
    # states, so every dialog is framed identically. See ActionViewHelpers#dialog.
    class Dialog
      SIZES = %i[default wide].freeze

      attr_reader :title_id

      def titled? = @title.present?

      def initialize(view, title: nil, size: :default, close: true, **options)
        unless SIZES.include?(size)
          raise ArgumentError, "unknown dialog size #{size.inspect} (expected one of #{SIZES.inspect})"
        end

        @view = view
        @title = title
        @size = size
        @close = close
        @options = options
        @title_id = "unmagic_dialog_#{SecureRandom.hex(4)}_title"
        @footer = nil
      end

      # The bottom row of actions — usually the form's submit.
      def footer(content = nil, &block)
        @footer = block ? view.capture(&block) : content
        nil
      end

      def render(body)
        classes = view.class_names("UnmagicDialog", { "UnmagicDialog--wide" => @size == :wide }, @options[:class])

        tag.div(**@options, class: classes) do
          safe_join [
            header,
            tag.div(body, class: "UnmagicDialog__body"),
            (tag.div(@footer, class: "UnmagicDialog__footer") if @footer.present?)
          ].compact
        end
      end

      # The close button on its own, for chrome built by hand.
      def self.close_button(view)
        label = I18n.t("unmagic.components.dialog.close", default: "Close")

        view.tag.button(
          Icons.svg(view, :x),
          type: "button", class: "#{Button.classes(:icon)} UnmagicDialog__close",
          "aria-label": label, data: { unmagic_dialog_close: "" }
        )
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def header
        return if @title.blank? && !@close

        tag.header class: "UnmagicDialog__header" do
          safe_join [
            (tag.h2(@title, id: title_id, class: "UnmagicDialog__title") if @title.present?),
            (self.class.close_button(view) if @close)
          ].compact
        end
      end
    end
  end
end
