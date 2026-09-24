# frozen_string_literal: true

module Unmagic
  module Components
    # Placeholder shapes for blocking out an interface while it loads. The same
    # object is what `skeleton do |s|` yields and what the standalone helpers
    # (skeleton_text, skeleton_circle, …) call, so the two forms can't differ. See
    # ActionViewHelpers#skeleton.
    #
    # Every shape is hidden from assistive technology; a group says "Loading…" once
    # for all of them.
    class Skeleton
      BUTTON_SIZES = %i[small large].freeze

      # The last line of a paragraph is shorter, so a block of text reads as one.
      LAST_LINE_WIDTH = "60%"

      # The public shapes, which is what a table column's skeleton: symbol may name.
      SHAPES = %i[text circle block button badge icon item].freeze

      # A row of pills narrows as it goes, so it reads as chips rather than one bar.
      # The first takes the CSS default.
      BADGE_WIDTHS = [ nil, "3.5rem", "3rem", "3.75rem" ].freeze

      # An item's description line, as a share of its title line.
      DESCRIPTION_WIDTH = 0.7

      # A status region around some shapes, announced once.
      def self.group(view, label: nil, **options)
        view.tag.div(**options, role: "status", class: view.class_names("UnmagicSkeletonGroup", options[:class])) do
          view.safe_join [ hidden_label(view, label), yield ]
        end
      end

      # The words a screen reader hears in place of the shapes.
      def self.hidden_label(view, label = nil)
        label ||= I18n.t("unmagic.components.skeleton.loading", default: "Loading…")
        view.tag.span(label, class: "UnmagicVisuallyHidden")
      end

      def initialize(view)
        @view = view
      end

      # A line of text, sized by the font it sits in: it takes exactly one line box,
      # so the text that replaces it lands in the same space. lines: renders a
      # paragraph instead, with a shorter last line; width: then applies to the whole.
      # class: and style: go on the line, width: on its bar.
      def text(width: nil, lines: 1, **options)
        raise ArgumentError, "skeleton text needs at least one line (got #{lines.inspect})" unless lines.to_i >= 1

        return line(width: width, **options) if lines == 1

        lines = Array.new(lines) { |index| line(width: (LAST_LINE_WIDTH if index == lines - 1)) }
        view.tag.span(view.safe_join(lines), **options, "aria-hidden": "true",
          class: view.class_names("UnmagicSkeletonText", options[:class]), style: style(options[:style], width: width))
      end

      # An avatar or a round icon.
      def circle(size: "2.5rem", **options)
        shape("circle", width: size, height: size, **options)
      end

      # An image, a chart, a map: anything rectangular. Full width unless given one.
      def block(height: "8rem", width: nil, **options)
        shape("block", width: width, height: height, **options)
      end

      # The size of a button_classes button, so a row of actions keeps its height.
      def button(size: nil, width: nil, **options)
        unless size.nil? || BUTTON_SIZES.include?(size)
          raise ArgumentError, "unknown skeleton button size #{size.inspect} (expected one of #{BUTTON_SIZES.inspect})"
        end

        shape("button", width: width, modifier: ("UnmagicSkeleton--#{size}" if size), **options)
      end

      # A badge's pill, the same height. count: renders a row of them that doesn't
      # wrap, for a run of chips; width: then applies to each.
      def badge(width: nil, count: 1, **options)
        raise ArgumentError, "skeleton badge needs at least one pill (got #{count.inspect})" unless count.to_i >= 1

        return shape("badge", width: width, **options) if count == 1

        pills = Array.new(count) { |index| shape("badge", width: width || BADGE_WIDTHS[index % BADGE_WIDTHS.size]) }
        view.tag.span(view.safe_join(pills), **options, "aria-hidden": "true",
          class: view.class_names("UnmagicSkeletonBadges", options[:class]))
      end

      # An icon-only button (button_classes(:icon)): a square its size.
      def icon(**options)
        shape("icon", **options)
      end

      # The item media object: an optional avatar, a title line and a smaller,
      # shorter description line under it. avatar: takes an avatar's size; width:
      # sizes the title, and the description is a share of it.
      def item(avatar: nil, description: true, width: nil, **options)
        Avatar.validate!(avatar, :circle) if avatar

        lines = [ line(width: width) ]
        lines << view.tag.span(line(width: description_width(width)), class: "UnmagicSkeletonItem__description") if description

        view.tag.span(**options, "aria-hidden": "true",
          class: view.class_names("UnmagicSkeletonItem", options[:class]), style: style(options[:style])) do
          view.safe_join [
            (circle(size: Avatar::DIMENSIONS.fetch(avatar)) if avatar),
            view.tag.span(view.safe_join(lines), class: "UnmagicSkeletonItem__main")
          ].compact
        end
      end

      private

      attr_reader :view

      # One line box of the surrounding font (1lh tall) with the bar centred in it.
      # The bar is thinner than the text so it reads as a placeholder, and the line
      # box, not margins around the bar, supplies the rest of the height: margins
      # would collapse through their container and the skeleton would come out
      # shorter than the text it stands in for.
      def line(width: nil, **options)
        view.tag.span(**options, "aria-hidden": "true",
          class: view.class_names("UnmagicSkeletonLine", options[:class]), style: style(options[:style])) do
          shape("text", width: width)
        end
      end

      def description_width(width)
        width ? "calc(#{width} * #{DESCRIPTION_WIDTH})" : "#{(DESCRIPTION_WIDTH * 100).round}%"
      end

      def shape(kind, width: nil, height: nil, modifier: nil, **options)
        view.tag.span(**options, "aria-hidden": "true",
          class: view.class_names("UnmagicSkeleton", "UnmagicSkeleton--#{kind}", modifier, options[:class]),
          style: style(options[:style], width: width, height: height))
      end

      def style(extra, **dimensions)
        rules = dimensions.compact.map { |property, value| "#{property}: #{value}" }
        rules << extra if extra.present?
        rules.join("; ").presence
      end
    end
  end
end
