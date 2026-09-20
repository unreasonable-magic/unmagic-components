# frozen_string_literal: true

module Unmagic
  module Components
    # Links to the pages around this one. See ActionViewHelpers#pagination.
    class Pagination
      def initialize(view, pager, window: 2, turbo_frame: nil, label: nil, **options)
        @view = view
        @pager = pager
        @window = window
        @turbo_frame = turbo_frame
        @label = label || I18n.t("unmagic.components.pagination.label", default: "Pagination")
        @options = options
      end

      # A pager that speaks previous, next and page_url is enough for the arrows;
      # one that also knows its page and last gets the numbers. One page of
      # results has nothing to page, so renders nothing.
      def render
        return unless pageable?
        return if @pager.previous.nil? && @pager.next.nil?

        tag.nav(**@options, "aria-label": @label, class: view.class_names("UnmagicPagination", @options[:class])) do
          safe_join [
            arrow(:previous, I18n.t("unmagic.components.pagination.previous", default: "Previous")),
            (numbers if numbered?),
            (count if numbered?),
            arrow(:next, I18n.t("unmagic.components.pagination.next", default: "Next"))
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def pageable? = %i[previous next page_url].all? { |m| @pager.respond_to?(m) }

      def numbered? = @pager.respond_to?(:page) && @pager.respond_to?(:last) && @pager.last.to_i > 1

      def data = ({ turbo_frame: @turbo_frame, turbo_action: "advance" } if @turbo_frame)

      def arrow(direction, label)
        if @pager.public_send(direction)
          view.link_to(label, @pager.page_url(direction), class: "UnmagicPagination__link", data: data, rel: direction == :previous ? "prev" : "next")
        else
          tag.span(label, class: "UnmagicPagination__link", "aria-disabled": "true")
        end
      end

      # The first and last pages, the pages within the window of this one, and a
      # gap wherever pages are skipped.
      def numbers
        current, last = @pager.page.to_i, @pager.last.to_i
        shown = ([ 1, last ] + ((current - @window)..(current + @window)).to_a).select { |n| n.between?(1, last) }.uniq.sort

        tag.ol class: "UnmagicPagination__pages" do
          safe_join(shown.each_with_index.map do |page, index|
            gap = index.positive? && page > shown[index - 1] + 1

            tag.li class: "UnmagicPagination__page" do
              safe_join [
                (tag.span("…", class: "UnmagicPagination__gap", "aria-hidden": "true") if gap),
                if page == current
                  tag.span(page, class: "UnmagicPagination__number", "aria-current": "page")
                else
                  view.link_to(page, @pager.page_url(page), class: "UnmagicPagination__number", data: data,
                    "aria-label": I18n.t("unmagic.components.pagination.page", page: page, default: "Page %{page}"))
                end
              ].compact
            end
          end)
        end
      end

      # On a narrow screen the numbers give way to "3 of 12".
      def count
        tag.span(I18n.t("unmagic.components.pagination.of", page: @pager.page, last: @pager.last, default: "%{page} of %{last}"),
          class: "UnmagicPagination__count")
      end
    end
  end
end
