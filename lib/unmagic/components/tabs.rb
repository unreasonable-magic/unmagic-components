# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A row of tabs: either panels switched in the page, or links to separate URLs.
    # See ActionViewHelpers#tabs.
    class Tabs
      STYLES = %i[segmented bar].freeze

      def initialize(view, id: nil, style: :segmented, **options)
        unless STYLES.include?(style)
          raise ArgumentError, "unknown tabs style #{style.inspect} (expected one of #{STYLES.inspect})"
        end

        @view = view
        @id = id
        @base = id || "unmagic_tabs_#{SecureRandom.hex(4)}"
        @style = style
        @options = options
        @tabs = []
        @panels = []
      end

      # icon: is a symbol from the gem's Lucide set, or rendered markup from the
      # host's own icons.
      def tab(label, disabled: nil, href: nil, active: false, icon: nil)
        @tabs << { label: label, disabled: disabled, href: href, active: active, icon: icon }
        nil
      end

      def panel(&block)
        @panels << view.capture(&block)
        nil
      end

      def render
        validate!

        if links?
          tag.nav(**@options, id: @id, class: classes) { list }
        else
          view.content_tag("unmagic-tabs", **@options, id: @id, class: classes) { safe_join [ list, *panels ] }
        end
      end

      # Tabs with href: are each their own URL, rendered on the server: navigation,
      # not a widget, so it needs no script and marks the current page rather than
      # a selected tab.
      def links? = @tabs.any? { |tab| tab[:href] }

      # Panels line up with the enabled tabs in order; a disabled tab takes none.
      def validate!
        raise ArgumentError, "tabs can't mix href: tabs with panels" if links? && @panels.any?

        if !links? && enabled.size != @panels.size
          raise ArgumentError, "tabs has #{enabled.size} enabled tabs but #{@panels.size} panels"
        end
      end

      # The list and the panels are also drawn apart, by a panel that puts the list
      # in a card's bar and the panels in its body.
      def list
        index = -1

        items = @tabs.map do |tab|
          next disabled_tab(tab) if tab[:disabled]

          if links?
            view.link_to label(tab), tab[:href], class: "UnmagicTabs__tab", "aria-current": ("page" if tab[:active])
          else
            index += 1
            tag.button label(tab), type: "button", role: "tab", id: "#{@base}_tab_#{index}", class: "UnmagicTabs__tab",
              "aria-controls": "#{@base}_panel_#{index}", "aria-selected": (index == selected).to_s,
              tabindex: (index == selected ? 0 : -1)
          end
        end

        tag.div safe_join(items), role: ("tablist" unless links?), class: "UnmagicTabs__list"
      end

      def panels
        @panels.each_with_index.map do |content, i|
          tag.div content, role: "tabpanel", id: "#{@base}_panel_#{i}", class: "UnmagicTabs__panel",
            "aria-labelledby": "#{@base}_tab_#{i}", tabindex: 0, hidden: i != selected
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def enabled = @tabs.reject { |tab| tab[:disabled] }

      def selected = enabled.index { |tab| tab[:active] } || 0

      def classes = view.class_names("UnmagicTabs", { "UnmagicTabs--bar" => @style == :bar }, @options[:class])

      def label(tab)
        safe_join [ icon(tab[:icon]), tab[:label] ].compact
      end

      def icon(icon)
        case icon
        when nil then nil
        when Symbol then Icons.svg(view, icon, class: "UnmagicTabs__icon")
        else icon
        end
      end

      def disabled_tab(tab)
        reason = tab[:disabled] unless tab[:disabled] == true

        tag.span class: "UnmagicTabs__tab", "aria-disabled": "true" do
          safe_join [ label(tab), (tag.span("(#{reason})", class: "UnmagicTabs__reason") if reason) ].compact, " "
        end
      end
    end
  end
end
