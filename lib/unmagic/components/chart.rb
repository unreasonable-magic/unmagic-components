# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

module Unmagic
  module Components
    # A chart drawn as inline SVG: columns over a set of labels, stacked where
    # there is more than one series, or a line over time. See
    # ActionViewHelpers#chart.
    #
    # Drawn to the rules a chart is read by rather than looked at: thin marks
    # that never fill their slot, a rounded cap and a square foot, hairline
    # gridlines one shade off the surface, a gap of surface between stacked
    # segments rather than a stroke around them, and the axis carrying the
    # numbers rather than a label on every column. Every column carries a
    # <title>, the browser's own tooltip, and the numbers are also laid out as a
    # table under a disclosure, so nothing a reader wants is only reachable by
    # hovering.
    class Chart
      TYPES = %i[column line].freeze
      FORMATS = %i[count money percent].freeze
      SLOTS = 6

      WIDTH = 720
      HEIGHT = 200
      GUTTER_LEFT = 56
      GUTTER_BOTTOM = 24
      GUTTER_TOP = 12
      GUTTER_RIGHT = 8
      COLUMN_MAX = 24
      COLUMN_GAP = 2
      RADIUS = 4

      # labels: the columns (or the points along a line), in order; series: one
      # { label:, values: } per series, values keyed by the label (or an array in
      # the same order), with an optional total: shown in the legend. A nil value
      # on a line is a gap the line doesn't bridge.
      def initialize(view, series, labels:, type: :column, format: :count, title: nil, width: WIDTH, legend: true,
        table: true, max: nil, label_format: nil, **options)
        raise ArgumentError, "unknown chart type #{type.inspect} (expected one of #{TYPES.inspect})" unless TYPES.include?(type)
        raise ArgumentError, "unknown chart format #{format.inspect} (expected one of #{FORMATS.inspect})" unless FORMATS.include?(format)
        raise ArgumentError, "chart needs at least one series" if series.blank?

        @view = view
        @labels = labels.to_a
        @series = series.each_with_index.map { |line, index| normalise(line, index) }
        @type = type
        @format = format
        @title = title
        @width = width
        @legend = legend
        @table = table
        @max = max
        @label_format = label_format
        @options = options
      end

      def render
        tag.figure(**@options, class: view.class_names("UnmagicChart", "UnmagicChart--#{@type}", @options[:class])) do
          safe_join [
            (head if @title.present? || (@legend && @series.many?)),
            drawing,
            (numbers if @table)
          ].compact
        end
      end

      # How a value reads on the axis, in a legend and in a tooltip.
      def reading(value)
        value = value.to_d
        case @format
        when :percent then "#{value.round}%"
        when :money
          value >= 10 || value.zero? ? view.number_to_currency(value, precision: 0) : view.number_to_currency(value)
        else
          if value >= 1000
            view.number_to_human value, units: { thousand: "K", million: "M", billion: "B" }, format: "%n%u",
              precision: 3, significant: true, strip_insignificant_zeros: true
          else
            view.number_with_delimiter value.to_i
          end
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def normalise(line, index)
        values = line[:values]
        values = @labels.zip(values).to_h if values.is_a?(Array)
        { label: line[:label], values: values || {}, total: line[:total], slot: line[:slot] || (index % SLOTS) + 1 }
      end

      def value_at(line, label) = line[:values][label]

      def head
        tag.figcaption class: "UnmagicChart__head" do
          safe_join [
            (tag.span(@title, class: "UnmagicChart__title") if @title.present?),
            (legend if @legend && @series.many?)
          ].compact
        end
      end

      def legend
        tag.ul class: "UnmagicChart__legend" do
          safe_join(@series.map do |line|
            tag.li class: "UnmagicChart__series" do
              safe_join [
                tag.span(class: "UnmagicChart__swatch UnmagicChart__swatch--#{line[:slot]}", "aria-hidden": "true"),
                line[:label],
                (tag.span("· #{reading(line[:total])}", class: "UnmagicChart__total") if line[:total])
              ].compact, " "
            end
          end)
        end
      end

      def plot_height = HEIGHT - GUTTER_TOP - GUTTER_BOTTOM

      def drawing
        tag.svg viewBox: "0 0 #{@width} #{HEIGHT}", class: "UnmagicChart__svg", role: "img", "aria-label": @title do
          @type == :column ? columns : line
        end
      end

      # ----------------------------------------------------------- columns

      def columns
        top = ceiling(@labels.map { |label| @series.sum { |line| value_at(line, label).to_d } }.max.to_d)
        slot = (@width - GUTTER_LEFT - GUTTER_RIGHT).to_f / [ @labels.size, 1 ].max
        column = [ COLUMN_MAX, slot - COLUMN_GAP ].min
        scale = ->(value) { (plot_height * value / top).to_f }

        safe_join [ gridlines(top), column_marks(slot, column, scale), column_labels(slot) ]
      end

      def column_marks(slot, column, scale)
        baseline = HEIGHT - GUTTER_BOTTOM

        safe_join @labels.each_with_index.map { |label, index|
          x = GUTTER_LEFT + slot * index + (slot - column) / 2
          stacked = @series.map { |line| [ line, value_at(line, label).to_d ] }.reject { |_, value| value.zero? }

          tag.g class: "UnmagicChart__column" do
            safe_join [
              tag.title(tooltip(label, stacked)),
              tag.rect(x: GUTTER_LEFT + slot * index, y: GUTTER_TOP, width: slot, height: baseline - GUTTER_TOP, class: "UnmagicChart__hit"),
              segments(stacked, x, column, baseline, scale)
            ]
          end
        }
      end

      # The stack, foot to cap. Every segment but the lowest gives up two pixels
      # at its foot to the surface, which keeps two colours apart without a
      # stroke; only the topmost is rounded.
      def segments(stacked, x, width, baseline, scale)
        bottom = baseline

        safe_join stacked.each_with_index.map { |(line, value), position|
          height = scale.call(value)
          foot = position.zero? ? 0 : COLUMN_GAP
          top = bottom - height
          drawn = height - foot
          bottom = top

          if drawn.positive?
            radius = position == stacked.size - 1 ? [ RADIUS, drawn / 2 ].min : 0
            tag.path d: column_path(x, top, width, drawn, radius), class: "UnmagicChart__mark UnmagicChart__mark--#{line[:slot]}"
          end
        }
      end

      def column_path(x, y, width, height, radius)
        [
          "M#{x.round(2)},#{(y + radius).round(2)}",
          "a#{radius},#{radius} 0 0 1 #{radius},-#{radius}",
          "h#{(width - 2 * radius).round(2)}",
          "a#{radius},#{radius} 0 0 1 #{radius},#{radius}",
          "v#{(height - radius).round(2)}",
          "h-#{width.round(2)}",
          "z"
        ].join(" ")
      end

      def tooltip(label, stacked)
        lines = stacked.reverse.map { |line, value| "#{reading(value)} #{line[:label]}" }
        [ label_text(label), *lines.presence || [ I18n.t("unmagic.components.chart.nothing", default: "nothing") ] ].join("\n")
      end

      # As many labels along the bottom as the width has room for, one every
      # ninety units or so, and always the last.
      def column_labels(slot)
        room = [ 1, ((@width - GUTTER_LEFT - GUTTER_RIGHT) / 90.0).floor ].max
        step = [ 1, (@labels.size / room.to_f).ceil ].max
        shown = @labels.each_index.select { |index| (index % step).zero? && index < @labels.size - step / 2 } | [ @labels.size - 1 ]

        safe_join shown.map { |index|
          tag.text label_text(@labels[index]), x: (GUTTER_LEFT + slot * index + slot / 2).round(2), y: HEIGHT - 6, "text-anchor": "middle"
        }
      end

      # -------------------------------------------------------------- line

      def line
        top = @max ? @max.to_d : ceiling(@series.flat_map { |l| @labels.map { |label| value_at(l, label) } }.compact.map(&:to_d).max.to_d)
        step = (@width - GUTTER_LEFT - GUTTER_RIGHT).to_f / [ @labels.size - 1, 1 ].max
        at = ->(index, value) { [ GUTTER_LEFT + step * index, GUTTER_TOP + plot_height - (plot_height * value.to_d.clamp(0, top) / top).to_f ] }

        safe_join [
          gridlines(top),
          safe_join(@series.map { |l| tag.path(d: line_path(l, at), class: "UnmagicChart__line UnmagicChart__line--#{l[:slot]}") }),
          safe_join(@series.map { |l| latest(l, at) }.compact),
          line_hits(step),
          line_labels(step)
        ]
      end

      def line_path(line, at)
        drawn = []
        pen_down = false

        @labels.each_with_index do |label, index|
          value = value_at(line, label)
          if value.nil?
            pen_down = false
          else
            x, y = at.call(index, value)
            drawn << "#{pen_down ? "L" : "M"}#{x.round(1)},#{y.round(1)}"
            pen_down = true
          end
        end

        drawn.join(" ")
      end

      def latest(line, at)
        index = @labels.rindex { |label| !value_at(line, label).nil? }
        return unless index

        x, y = at.call(index, value_at(line, @labels[index]))
        tag.circle cx: x.round(1), cy: y.round(1), r: 4, class: "UnmagicChart__dot UnmagicChart__dot--#{line[:slot]}"
      end

      def line_hits(step)
        safe_join @labels.each_with_index.map { |label, index|
          readings = @series.map { |l| v = value_at(l, label); "#{v.nil? ? I18n.t("unmagic.components.chart.no_reading", default: "no reading") : reading(v)} #{l[:label]}" }
          tag.g class: "UnmagicChart__column" do
            safe_join [
              tag.title([ label_text(label), *readings ].join("\n")),
              tag.rect(x: (GUTTER_LEFT + step * (index - 0.5)).round(1), y: GUTTER_TOP, width: step.round(2), height: plot_height, class: "UnmagicChart__hit")
            ]
          end
        }
      end

      def line_labels(step)
        count = [ 2, [ (@width >= WIDTH ? 6 : 4), @labels.size ].min ].max
        shown = (0...count).map { |n| ((@labels.size - 1) * n / (count - 1).to_f).round }.uniq

        safe_join shown.map { |index|
          anchor = index.zero? ? "start" : (index == @labels.size - 1 ? "end" : "middle")
          tag.text label_text(@labels[index]), x: (GUTTER_LEFT + step * index).round(1), y: HEIGHT - 6, "text-anchor": anchor
        }
      end

      # ------------------------------------------------------------ shared

      def gridlines(top)
        safe_join [ 0, top / 2, top ].map { |value|
          y = GUTTER_TOP + plot_height - (plot_height * value / top).to_f
          safe_join [
            tag.line(x1: GUTTER_LEFT, x2: @width - GUTTER_RIGHT, y1: y, y2: y, class: value.zero? ? "UnmagicChart__axis" : "UnmagicChart__grid"),
            tag.text(reading(value), x: GUTTER_LEFT - 8, y: y + 4, "text-anchor": "end")
          ]
        }
      end

      # The smallest of 1, 2, 4, 5 or 10 at some power of ten that clears the
      # tallest value, so the halfway rule is a round number too.
      def ceiling(max)
        return 1.to_d if max <= 0

        magnitude = 10.to_d**Math.log10(max).floor
        [ 1, 2, 4, 5, 10 ].map { |step| step * magnitude }.detect { |ceiling| ceiling >= max }
      end

      def label_text(label)
        return @label_format.call(label) if @label_format
        return label.strftime("%-d %b") if label.respond_to?(:strftime)

        label.to_s
      end

      # The same numbers as a table, for anybody who can't or won't hover:
      # only the labels with anything in them.
      def numbers
        listed = @labels.select { |label| @series.any? { |l| !value_at(l, label).nil? && value_at(l, label).to_d != 0 } }
        return if listed.empty?

        tag.details class: "UnmagicChart__table" do
          safe_join [
            tag.summary(I18n.t("unmagic.components.chart.as_table", default: "As a table")),
            view.table_tag(
              [ I18n.t("unmagic.components.chart.label", default: "Label"), *@series.map { |l| l[:label] } ],
              listed.map { |label| [ label_text(label), *@series.map { |l| v = value_at(l, label); v.nil? ? "—" : reading(v) } ] },
              aligns: [ nil, *@series.map { :right } ], class: "UnmagicChart__numbers"
            )
          ]
        end
      end
    end
  end
end
