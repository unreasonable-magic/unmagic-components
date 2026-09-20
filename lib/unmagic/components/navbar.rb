# frozen_string_literal: true

module Unmagic
  module Components
    # The bar across the top of an app: a brand, a run of links, and the actions
    # at the end; the links fold behind a menu button on a narrow screen. See
    # ActionViewHelpers#navbar.
    class Navbar
      COLLAPSES = [ :sm, :md, :lg, false ].freeze

      def initialize(view, label: nil, sticky: false, collapse: :md, **options)
        unless COLLAPSES.include?(collapse)
          raise ArgumentError, "unknown navbar collapse #{collapse.inspect} (expected one of #{COLLAPSES.inspect})"
        end

        @view = view
        @label = label || I18n.t("unmagic.components.navbar.label", default: "Main")
        @sticky = sticky
        @collapse = collapse
        @options = options
        @brand = nil
        @links = []
        @actions = nil
      end

      def brand(url = nil, content = nil, &block)
        content = view.capture(&block) if block
        @brand = url ? view.link_to(content, url, class: "UnmagicNavbar__brand") : tag.span(content, class: "UnmagicNavbar__brand")
        nil
      end

      def link(name = nil, url = nil, current: false, **options, &block)
        name, url = view.capture(&block), name if block
        @links << view.link_to(name, url, **options, "aria-current": ("page" if current),
          class: view.class_names("UnmagicNavbar__link", options[:class]))
        nil
      end

      def actions(content = nil, &block)
        @actions = block ? view.capture(&block) : content
        nil
      end

      def render
        classes = view.class_names("UnmagicNavbar", { "UnmagicNavbar--sticky" => @sticky, "UnmagicNavbar--collapse-#{@collapse}" => @collapse }, @options[:class])
        menu = I18n.t("unmagic.components.navbar.menu", default: "Menu")

        tag.header(**@options, class: classes) do
          view.content_tag("unmagic-navbar", class: "UnmagicNavbar__inner") do
            safe_join [
              @brand,
              (if @collapse
                 tag.details(class: "UnmagicNavbar__disclosure") do
                   tag.summary(Icons.svg(view, :menu), class: "#{Button.classes(:icon)} UnmagicNavbar__toggle", "aria-label": menu, title: menu)
                 end
               end),
              tag.nav(class: "UnmagicNavbar__nav", "aria-label": @label) do
                tag.ul(safe_join(@links.map { |link| tag.li(link) }), class: "UnmagicNavbar__links")
              end,
              (tag.div(@actions, class: "UnmagicNavbar__actions") if @actions.present?)
            ].compact
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
