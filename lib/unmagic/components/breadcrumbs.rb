# frozen_string_literal: true

module Unmagic
  module Components
    # The trail of pages above this one. See ActionViewHelpers#breadcrumbs.
    class Breadcrumbs
      def initialize(view, label: nil, **options)
        @view = view
        @label = label || I18n.t("unmagic.components.breadcrumbs.label", default: "Breadcrumb")
        @options = options
        @crumbs = []
        @current = nil
      end

      # link_to's arguments, block form included.
      def link(name = nil, url = nil, **options, &block)
        raise ArgumentError, "breadcrumbs can't add a link after current" if @current

        name, url = view.capture(&block), name if block
        @crumbs << view.link_to(name, url, **options, title: options.fetch(:title, name.to_s),
          class: view.class_names("UnmagicBreadcrumbs__link", options[:class]))
        nil
      end

      # The page you are on. Optional, since a trail can end on a link.
      def current(name = nil, **options, &block)
        raise ArgumentError, "breadcrumbs takes one current crumb" if @current

        @current = tag.span(block ? view.capture(&block) : name, **options, "aria-current": "page",
          class: view.class_names("UnmagicBreadcrumbs__current", options[:class]))
        nil
      end

      def render
        items = [ *@crumbs, @current ].compact
        return if items.empty?

        tag.nav(**@options, "aria-label": @label, class: view.class_names("UnmagicBreadcrumbs", @options[:class])) do
          tag.ol class: "UnmagicBreadcrumbs__list" do
            safe_join(items.each_with_index.map do |item, index|
              tag.li class: "UnmagicBreadcrumbs__item" do
                safe_join [ (Icons.svg(view, :chevron_right, class: "UnmagicBreadcrumbs__separator") unless index.zero?), item ].compact
              end
            end)
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
