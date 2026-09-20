# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A dropdown of actions behind a trigger, on the Popover API: the panel is in
    # the top layer, so nothing clips it. See ActionViewHelpers#menu, and
    # #context_menu for the same panel opened at the pointer.
    class Menu
      ALIGNMENTS = %i[start end].freeze
      TONES = %i[default danger].freeze

      def initialize(view, label: nil, align: :end, context: nil, id: nil, **options)
        unless ALIGNMENTS.include?(align)
          raise ArgumentError, "unknown menu align #{align.inspect} (expected one of #{ALIGNMENTS.inspect})"
        end

        @view = view
        @label = label
        @align = align
        @context = context
        @id = id
        @base = id || "unmagic_menu_#{SecureRandom.hex(4)}"
        @options = options
        @items = []
      end

      # A link item. Takes link_to's arguments, block form included.
      def link(name = nil, url = nil, tone: :default, icon: nil, **options, &block)
        name, url = view.capture(&block), name if block
        @items << view.link_to(label(name, icon), url, **options, role: "menuitem", class: item_classes(tone, options[:class]))
        nil
      end

      # A button_to item, for an action that isn't a GET. Takes button_to's
      # arguments, block form included, so form: { data: { turbo_confirm: } } works.
      def button(name = nil, url = nil, tone: :default, icon: nil, **options, &block)
        name, url = view.capture(&block), name if block
        @items << view.button_to(url, **options, role: "menuitem", class: item_classes(tone, options[:class]),
          form_class: "UnmagicMenu__form") { label(name, icon) }
        nil
      end

      # A plain button item with no form of its own, for wiring to something on
      # the page: opening a dialog, mostly. Options go on the <button>.
      def item(name = nil, tone: :default, icon: nil, **options, &block)
        name = view.capture(&block) if block
        @items << tag.button(label(name, icon), type: "button", **options, role: "menuitem", class: item_classes(tone, options[:class]))
        nil
      end

      # A heading over the items that follow.
      def section(title)
        @items << tag.p(title, class: "UnmagicMenu__section", role: "presentation")
        nil
      end

      # An item that folds out in place: the label is a summary, and the block (a
      # small form, usually) sits under it, so the whole exchange happens without
      # leaving the panel.
      def disclosure(name, icon: nil, &block)
        @items << tag.details(class: "UnmagicMenu__disclosure") do
          safe_join [
            tag.summary(class: "UnmagicMenu__item UnmagicMenu__summary") do
              safe_join [ label(name, icon), Icons.svg(view, :chevron_right, class: "UnmagicMenu__chevron") ]
            end,
            tag.div(view.capture(&block), class: "UnmagicMenu__fold")
          ]
        end
        nil
      end

      def divider
        @items << tag.hr(class: "UnmagicMenu__divider", role: "separator")
        nil
      end

      def render
        return "".html_safe if @context && @items.empty?

        element = @context ? "unmagic-context-menu" : "unmagic-menu"
        classes = view.class_names("UnmagicMenu", { "UnmagicMenu--context" => @context }, @options[:class])

        view.content_tag(element, **@options, id: @id, class: classes, align: (@align unless @context), for: @context) do
          safe_join [ (trigger unless @context), panel ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def panel_id = "#{@base}_panel"

      def panel
        tag.div(safe_join(@items), id: panel_id, popover: "auto", role: "menu",
          class: "UnmagicMenu__panel UnmagicMenu__panel--#{@align}", tabindex: -1,
          "aria-label": (@context ? (@label || I18n.t("unmagic.components.menu.actions", default: "Actions")) : nil))
      end

      def trigger
        attributes = { type: "button", popovertarget: panel_id, "aria-controls": panel_id, "aria-haspopup": "menu" }

        if @label
          tag.button(**attributes, class: "#{Button.classes} UnmagicMenu__trigger") do
            safe_join [ @label, Icons.svg(view, :chevron_down) ]
          end
        else
          label = I18n.t("unmagic.components.menu.label", default: "More actions")
          tag.button(Icons.svg(view, :ellipsis_vertical), **attributes, class: "#{Button.classes(:icon)} UnmagicMenu__trigger",
            "aria-label": label, title: label)
        end
      end

      def label(name, icon)
        glyph = icon.is_a?(Symbol) ? Icons.svg(view, icon) : icon
        glyph ? safe_join([ glyph, name ]) : name
      end

      def item_classes(tone, extra)
        unless TONES.include?(tone)
          raise ArgumentError, "unknown menu item tone #{tone.inspect} (expected one of #{TONES.inspect})"
        end

        view.class_names("UnmagicMenu__item", { "UnmagicMenu__item--danger" => tone == :danger }, extra)
      end
    end
  end
end
