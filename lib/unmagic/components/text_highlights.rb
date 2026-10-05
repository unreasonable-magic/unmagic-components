# frozen_string_literal: true

require "set"
require "nokogiri"

module Unmagic
  module Components
    # Marks passages of a text the way a highlighter pen would: a word, a
    # sentence, or everything from one quote to another, each in a colour. See
    # ActionViewHelpers#text_highlights and Messaging::Message#highlight.
    #
    # A passage is found by what it says, never by an offset, so a highlight
    # written by hand (or by a model) survives the text being re-rendered. The
    # matching forgives what a person can't see or wouldn't type: case, runs of
    # whitespace and line breaks, curly against straight quotes, dashes against
    # hyphens, an ellipsis against three dots. Each highlight marks the first
    # place it matches, as a URL's text fragment does (#:~:text=); quote more to
    # pick a later one. A range runs from the first match of from: to the first
    # match of to: after it.
    #
    # The marks are plain <mark> elements, put in on the server, so they show
    # without script, print, and reach the accessibility tree. HTML content is
    # parsed and its text nodes split, so one highlight can run across a link or
    # a paragraph break: it becomes one <mark> per piece, joined by
    # data-highlight (the highlight's index in the list).
    class TextHighlights
      COLORS = %i[yellow green blue pink red].freeze

      # One highlight as written: text: on its own, or from: and to:.
      Highlight = Data.define(:text, :from, :to, :color)

      # Where a highlight landed in the text: [start, finish) and its index.
      Match = Data.define(:start, :finish, :index, :color)

      # What a reader can't tell apart, folded to one spelling before matching.
      FOLDS = {
        "‘" => "'", "’" => "'", "‚" => "'", "‛" => "'", "′" => "'", "`" => "'",
        "“" => '"', "”" => '"', "„" => '"', "‟" => '"', "″" => '"', "«" => '"', "»" => '"',
        "‐" => "-", "‑" => "-", "‒" => "-", "–" => "-", "—" => "-", "―" => "-", "−" => "-",
        "…" => "..."
      }.freeze

      # Elements whose edges a reader sees as a break, so "end. Next" can match
      # across two paragraphs.
      BLOCKS = %w[
        address article aside blockquote br dd div dl dt figcaption figure footer h1 h2 h3 h4 h5 h6 header hr li
        main nav ol p pre section table td th tr ul
      ].to_set.freeze

      class << self
        # Highlights from what a caller wrote: a string (that text, in yellow), a
        # Hash (text:, or from: and to:, and color:), or a Highlight.
        def build(spec)
          case spec
          when Highlight then spec
          when String then Highlight.new(text: spec, from: nil, to: nil, color: :yellow)
          when Hash then from_hash(spec.symbolize_keys)
          else raise ArgumentError, "a highlight is a String or a Hash, not #{spec.inspect}"
          end
        end

        # Where each highlight lands in text, in the order given; one that isn't
        # there is left out. breaks are offsets a reader sees as whitespace though
        # the text has none there (a paragraph's edge).
        def matches(text, highlights, breaks: [])
          haystack, positions = fold(text, breaks.to_set)

          Array(highlights).each_with_index.filter_map do |highlight, index|
            highlight = build(highlight)
            found = locate(haystack, positions, highlight)
            Match.new(start: found.first, finish: found.last, index: index, color: highlight.color) if found
          end
        end

        # The text cut where highlights start and end: [start, finish, match]
        # covering all of it, match nil where nothing is marked. Where highlights
        # overlap, the one given later wins.
        def segments(length, matches)
          edges = ([ 0, length ] + matches.flat_map { |match| [ match.start, match.finish ] }).uniq.sort

          edges.each_cons(2).map do |start, finish|
            [ start, finish, matches.reverse.find { |match| match.start <= start && finish <= match.finish } ]
          end
        end

        private

        def from_hash(spec)
          spec.assert_valid_keys(:text, :from, :to, :color)
          color = (spec[:color].presence || :yellow).to_sym
          unless COLORS.include?(color)
            raise ArgumentError, "unknown text_highlights color #{color.inspect} (expected one of #{COLORS.inspect})"
          end
          if spec[:text].present? == (spec[:from].present? || spec[:to].present?)
            raise ArgumentError, "a highlight is text:, or from: and to:, not both or neither (#{spec.inspect})"
          end
          if spec[:text].blank? && (spec[:from].blank? || spec[:to].blank?)
            raise ArgumentError, "a highlight's range needs both from: and to: (#{spec.inspect})"
          end

          Highlight.new(text: spec[:text].presence, from: spec[:from].presence, to: spec[:to].presence, color: color)
        end

        # [start, finish) of a highlight in the original text, or nil.
        def locate(haystack, positions, highlight)
          if highlight.text
            found = find(haystack, positions, highlight.text, 0)
            found&.first(2)
          elsif (first = find(haystack, positions, highlight.from, 0))
            last = find(haystack, positions, highlight.to, first[2])
            [ first[0], last[1] ] if last
          end
        end

        # [start, finish, where the search for what follows begins] in the
        # original text, from a match in the folded one.
        def find(haystack, positions, needle, offset)
          needle, = fold(needle.to_s, Set.new)
          return if needle.empty?

          at = haystack.index(needle, offset)
          [ positions[at], positions[at + needle.length - 1] + 1, at + needle.length ] if at
        end

        # The text in one spelling, with the offset in the original that each of
        # its characters came from. Whitespace collapses to one space, and none
        # leads or trails.
        def fold(text, breaks)
          folded = +""
          positions = []
          space = false

          text.each_char.with_index do |char, offset|
            space = true if breaks.include?(offset)
            if char.match?(/[[:space:]]/)
              space = true
            else
              if space && !folded.empty?
                folded << " "
                positions << offset
              end
              space = false
              FOLDS.fetch(char) { char.downcase }.each_char do |piece|
                folded << piece
                positions << offset
              end
            end
          end

          [ folded, positions ]
        end
      end

      attr_reader :highlights

      def initialize(view, highlights)
        @view = view
        @highlights = (highlights.is_a?(Array) ? highlights : [ highlights ]).compact_blank.map { |spec| self.class.build(spec) }
        @matched = []
      end

      # The content with its passages marked: a plain string is text and comes
      # back escaped; an html_safe one is markup, and keeps its tags.
      def render(content)
        if highlights.empty? || content.blank?
          ERB::Util.html_escape(content.to_s)
        elsif content.html_safe?
          markup(content.to_str)
        else
          text(content.to_s)
        end
      end

      # The highlights the last render couldn't find in its content.
      def unmatched
        highlights.reject.with_index { |_highlight, index| @matched.include?(index) }
      end

      private

      attr_reader :view

      def text(content)
        matches = remember(self.class.matches(content, highlights))

        view.safe_join(self.class.segments(content.length, matches).map do |start, finish, match|
          piece = content[start...finish]
          match ? mark(match, piece) : piece
        end)
      end

      def mark(match, content)
        view.tag.mark(content, class: classes(match), data: { highlight: match.index })
      end

      def classes(match) = "UnmagicMark UnmagicMark--#{match.color}"

      # The text nodes, read in order as one string, are matched as plain text;
      # then each node is swapped for its pieces, marked where a match covers it.
      def markup(content)
        fragment = parse(content)
        nodes, breaks, length = text_nodes(fragment)
        joined = nodes.map { |node, _| node.content }.join
        matches = remember(self.class.matches(joined, highlights, breaks: breaks))
        segments = self.class.segments(length, matches).select { |_, _, match| match }

        nodes.each do |node, offset|
          finish = offset + node.content.length
          inside = segments.select { |start, stop, _| start < finish && stop > offset }
          split(node, offset, inside) if inside.any?
        end

        fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety -- re-serialised by Nokogiri, which escapes the text it holds
      end

      def parse(content)
        if defined?(Nokogiri::HTML5)
          Nokogiri::HTML5.fragment(content)
        else
          Nokogiri::HTML::DocumentFragment.parse(content)
        end
      end

      # [[node, offset]], the offsets where blocks begin and end, and the length.
      def text_nodes(fragment)
        nodes = []
        breaks = []
        offset = 0

        walk = lambda do |node|
          if node.text?
            nodes << [ node, offset ]
            offset += node.content.length
          elsif node.element? || node.fragment?
            block = node.element? && BLOCKS.include?(node.name)
            breaks << offset if block
            node.children.each(&walk)
            breaks << offset if block
          end
        end
        walk.call(fragment)

        [ nodes, breaks, offset ]
      end

      def split(node, offset, segments)
        content = node.content
        cursor = 0
        pieces = []

        segments.each do |start, finish, match|
          from = [ start - offset, 0 ].max
          to = [ finish - offset, content.length ].min
          pieces << node.document.create_text_node(content[cursor...from]) if from > cursor
          element = node.document.create_element("mark", class: classes(match), "data-highlight": match.index.to_s)
          element.content = content[from...to]
          pieces << element
          cursor = to
        end
        pieces << node.document.create_text_node(content[cursor..]) if cursor < content.length

        pieces.each { |piece| node.add_previous_sibling(piece) }
        node.remove
      end

      def remember(matches)
        @matched = matches.map(&:index)
        matches
      end
    end
  end
end
