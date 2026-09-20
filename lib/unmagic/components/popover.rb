# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A small panel of content behind a trigger: a form to rename something, a
    # card about a person. See ActionViewHelpers#popover.
    class Popover
      PLACEMENTS = %i[bottom top].freeze
      ALIGNS = %i[start center end].freeze
      SIZES = %i[default wide].freeze

      def initialize(view, label = nil, title: nil, placement: :bottom, align: :start, size: :default, id: nil, **options)
        raise ArgumentError, "unknown popover placement #{placement.inspect} (expected one of #{PLACEMENTS.inspect})" unless PLACEMENTS.include?(placement)
        raise ArgumentError, "unknown popover align #{align.inspect} (expected one of #{ALIGNS.inspect})" unless ALIGNS.include?(align)
        raise ArgumentError, "unknown popover size #{size.inspect} (expected one of #{SIZES.inspect})" unless SIZES.include?(size)

        @view = view
        @label = label
        @title = title
        @placement = placement
        @align = align
        @size = size
        @id = id
        @base = id || "unmagic_popover_#{SecureRandom.hex(4)}"
        @options = options
        @trigger = nil
        @footer = nil
      end

      # The trigger's own content, wrapped in the button. Don't nest a link or a
      # button in it.
      def trigger(content = nil, &block)
        @trigger = block ? view.capture(&block) : content
        nil
      end

      def footer(content = nil, &block)
        @footer = block ? view.capture(&block) : content
        nil
      end

      def render(body)
        raise ArgumentError, "popover needs a label or a trigger" if @label.blank? && @trigger.blank?

        view.content_tag("unmagic-popover", **@options, id: @id, placement: @placement, align: @align,
          class: view.class_names("UnmagicPopover", @options[:class])) do
          safe_join [ button, panel(body) ]
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def panel_id = "#{@base}_panel"

      def title_id = "#{@base}_title"

      def button
        attributes = { type: "button", popovertarget: panel_id, "aria-controls": panel_id }

        if @trigger
          tag.button(@trigger, **attributes, class: "UnmagicPopover__trigger UnmagicPopover__trigger--custom")
        else
          tag.button(**attributes, class: "#{Button.classes} UnmagicPopover__trigger") do
            safe_join [ @label, Icons.svg(view, :chevron_down) ]
          end
        end
      end

      def panel(body)
        tag.div(id: panel_id, popover: "auto", role: "dialog", tabindex: -1,
          "aria-labelledby": (title_id if @title.present?), "aria-label": (@label if @title.blank?),
          class: view.class_names("UnmagicPopover__panel", "UnmagicPopover__panel--wide" => @size == :wide)) do
          safe_join [
            (tag.h2(@title, id: title_id, class: "UnmagicPopover__title") if @title.present?),
            tag.div(body, class: "UnmagicPopover__body"),
            (tag.div(@footer, class: "UnmagicPopover__footer") if @footer.present?)
          ].compact
        end
      end
    end
  end
end
