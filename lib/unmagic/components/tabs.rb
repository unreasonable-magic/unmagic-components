# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A row of tabs: either panels switched in the page, or links to separate URLs.
    # See ActionViewHelpers#tabs.
    class Tabs
      def initialize(view, id: nil, **options)
        @view = view
        @id = id
        @base = id || "unmagic_tabs_#{SecureRandom.hex(4)}"
        @options = options
        @tabs = []
        @panels = []
      end

      def tab(label, disabled: nil, href: nil, active: false)
        @tabs << { label: label, disabled: disabled, href: href, active: active }
        nil
      end

      def panel(&block)
        @panels << view.capture(&block)
        nil
      end

      def render
        links = @tabs.any? { |tab| tab[:href] }
        raise ArgumentError, "tabs can't mix href: tabs with panels" if links && @panels.any?

        links ? links_bar : switcher
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def enabled = @tabs.reject { |tab| tab[:disabled] }

      # Panels line up with the enabled tabs in order; a disabled tab takes none.
      def switcher
        if enabled.size != @panels.size
          raise ArgumentError, "tabs has #{enabled.size} enabled tabs but #{@panels.size} panels"
        end

        selected = enabled.index { |tab| tab[:active] } || 0
        index = -1

        list = @tabs.map do |tab|
          next disabled_tab(tab) if tab[:disabled]

          index += 1
          tag.button tab[:label], type: "button", role: "tab", id: "#{@base}_tab_#{index}", class: "UnmagicTabs__tab",
            "aria-controls": "#{@base}_panel_#{index}", "aria-selected": (index == selected).to_s,
            tabindex: (index == selected ? 0 : -1)
        end

        panels = @panels.each_with_index.map do |content, i|
          tag.div content, role: "tabpanel", id: "#{@base}_panel_#{i}", class: "UnmagicTabs__panel",
            "aria-labelledby": "#{@base}_tab_#{i}", tabindex: 0, hidden: i != selected
        end

        view.content_tag("unmagic-tabs", **@options, id: @id, class: view.class_names("UnmagicTabs", @options[:class])) do
          safe_join [ tag.div(safe_join(list), role: "tablist", class: "UnmagicTabs__list"), *panels ]
        end
      end

      # Each tab its own URL, rendered on the server: navigation, not a widget, so it
      # needs no script and marks the current page rather than a selected tab.
      def links_bar
        tag.nav(**@options, id: @id, class: view.class_names("UnmagicTabs", @options[:class])) do
          tag.div class: "UnmagicTabs__list" do
            safe_join(@tabs.map do |tab|
              next disabled_tab(tab) if tab[:disabled]

              view.link_to tab[:label], tab[:href], class: "UnmagicTabs__tab", "aria-current": ("page" if tab[:active])
            end)
          end
        end
      end

      def disabled_tab(tab)
        reason = tab[:disabled] unless tab[:disabled] == true

        tag.span class: "UnmagicTabs__tab", "aria-disabled": "true" do
          safe_join [ tab[:label], (tag.span("(#{reason})", class: "UnmagicTabs__reason") if reason) ].compact, " "
        end
      end
    end
  end
end
