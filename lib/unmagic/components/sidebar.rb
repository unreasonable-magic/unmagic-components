# frozen_string_literal: true

module Unmagic
  module Components
    # The navigation down the side of an app: sections of links with icons and
    # counts, a header and a footer, a sheet from the edge on a narrow screen.
    # See ActionViewHelpers#sidebar.
    class Sidebar
      BREAKPOINTS = %i[md lg never].freeze

      def initialize(view, id:, label: nil, collapse_below: :lg, **options)
        unless BREAKPOINTS.include?(collapse_below)
          raise ArgumentError, "unknown sidebar collapse_below #{collapse_below.inspect} (expected one of #{BREAKPOINTS.inspect})"
        end

        @view = view
        @id = id
        @label = label || I18n.t("unmagic.components.sidebar.label", default: "Main")
        @collapse_below = collapse_below
        @options = options
        @header = nil
        @footer = nil
        @sections = []
      end

      def header(content = nil, &block)
        @header = block ? view.capture(&block) : content
        nil
      end

      def footer(content = nil, &block)
        @footer = block ? view.capture(&block) : content
        nil
      end

      # A run of links, with a title or without; collapsible: true folds it on a
      # <details>, open when it holds the current page or with open: true.
      def section(title = nil, collapsible: false, open: nil, &block)
        section = Section.new(view)
        view.capture(section, &block)
        @sections << [ title, collapsible, open, section ]
        nil
      end

      def render
        classes = view.class_names("UnmagicSidebar", "UnmagicSidebar--below-#{@collapse_below}", @options[:class])

        view.content_tag("unmagic-sidebar", **@options, class: classes) do
          tag.nav(id: @id, class: "UnmagicSidebar__panel", "aria-label": @label, popover: ("auto" unless @collapse_below == :never)) do
            safe_join [
              (tag.div(@header, class: "UnmagicSidebar__header") if @header.present?),
              *@sections.map { |title, collapsible, open, section| section_tag(title, collapsible, open, section) },
              (tag.div(@footer, class: "UnmagicSidebar__footer") if @footer.present?)
            ].compact
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def section_tag(title, collapsible, open, section)
        return tag.div(section.list, class: "UnmagicSidebar__section") if title.blank?

        if collapsible
          tag.details(class: "UnmagicSidebar__section", open: (open.nil? ? section.current? : open) || nil) do
            safe_join [
              tag.summary(class: "UnmagicSidebar__title UnmagicSidebar__title--summary") do
                safe_join [ title, Icons.svg(view, :chevron_down, class: "UnmagicSidebar__chevron") ]
              end,
              section.list
            ]
          end
        else
          id = "#{@id}_#{title.to_s.parameterize.underscore}"
          tag.div(class: "UnmagicSidebar__section") do
            safe_join [ tag.h2(title, id: id, class: "UnmagicSidebar__title"), section.list("aria-labelledby": id) ]
          end
        end
      end

      class Section
        def initialize(view)
          @view = view
          @links = []
          @current = false
        end

        def current? = @current

        # link_to's arguments, plus icon: (a symbol from the gem's set or markup),
        # badge: (a count; blank or zero renders nothing) and active: (nil falls
        # back to current_page?).
        def link(name, url, icon: nil, badge: nil, active: nil, **options)
          active = @view.current_page?(url) if active.nil? && @view.respond_to?(:current_page?)
          @current ||= active
          glyph = icon.is_a?(Symbol) ? Icons.svg(@view, icon) : icon
          count = badge.presence && badge.to_s != "0" ? @view.tag.span(badge, class: Badge.classes(:neutral)) : nil

          @links << @view.link_to(url, **options, "aria-current": ("page" if active),
            class: @view.class_names("UnmagicSidebar__link", options[:class])) do
            @view.safe_join [
              (@view.tag.span(glyph, class: "UnmagicSidebar__icon") if glyph),
              @view.tag.span(name, class: "UnmagicSidebar__text"),
              count
            ].compact
          end
          nil
        end

        def list(**attributes)
          @view.tag.ul(class: "UnmagicSidebar__list", role: "list", **attributes) do
            @view.safe_join(@links.map { |link| @view.tag.li(link) })
          end
        end
      end
    end
  end
end
