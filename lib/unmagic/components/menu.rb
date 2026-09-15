# frozen_string_literal: true

module Unmagic
  module Components
    # A dropdown of actions behind a trigger, built on <details>. See
    # ActionViewHelpers#menu.
    class Menu
      ALIGNMENTS = %i[start end].freeze
      TONES = %i[default danger].freeze

      def initialize(view, label:, align:, **options)
        unless ALIGNMENTS.include?(align)
          raise ArgumentError, "unknown menu align #{align.inspect} (expected one of #{ALIGNMENTS.inspect})"
        end

        @view = view
        @label = label
        @align = align
        @options = options
        @items = []
      end

      # A link item. Takes link_to's arguments, block form included.
      def link(name = nil, url = nil, tone: :default, **options, &block)
        name, url = view.capture(&block), name if block
        @items << view.link_to(name, url, **options, role: "menuitem", class: item_classes(tone, options[:class]))
        nil
      end

      # A button_to item, for an action that isn't a GET. Takes button_to's
      # arguments, block form included, so form: { data: { turbo_confirm: } } works.
      def button(name = nil, url = nil, tone: :default, **options, &block)
        name, url = view.capture(&block), name if block
        @items << view.button_to(url, **options, role: "menuitem", class: item_classes(tone, options[:class]),
          form_class: "UnmagicMenu__form") { name }
        nil
      end

      def divider
        @items << tag.hr(class: "UnmagicMenu__divider", role: "separator")
        nil
      end

      def render
        view.content_tag("unmagic-menu", **@options, class: view.class_names("UnmagicMenu", @options[:class])) do
          tag.details class: "UnmagicMenu__details" do
            safe_join [
              trigger,
              tag.div(safe_join(@items), class: "UnmagicMenu__panel UnmagicMenu__panel--#{@align}", role: "menu")
            ]
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def trigger
        if @label
          tag.summary(class: "#{Button.classes} UnmagicMenu__trigger", "aria-haspopup": "menu") do
            safe_join [ @label, Icons.svg(view, :chevron_down) ]
          end
        else
          label = I18n.t("unmagic.components.menu.label", default: "More actions")
          tag.summary(Icons.svg(view, :ellipsis_vertical), class: "#{Button.classes(:icon)} UnmagicMenu__trigger",
            "aria-haspopup": "menu", "aria-label": label, title: label)
        end
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
