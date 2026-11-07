# frozen_string_literal: true

require "securerandom"
require "active_support/core_ext/string/strip"

module Unmagic
  module Components
    # A block of source to read or copy: coloured, optionally numbered, wrapping
    # or scrolling sideways. See ActionViewHelpers#code_view.
    class CodeView
      # A snippet written into a template arrives with the template's indentation
      # and a newline either side; this takes those off, the way a squiggly heredoc
      # does, and hands back a plain string so nothing it holds counts as markup.
      def self.snippet(captured)
        String.new(captured.to_s).gsub(/\A\s*\n|\s+\z/, "").strip_heredoc.chomp
      end

      def initialize(view, source, language: nil, lines: false, wrap: true, max_height: nil, copy: true,
        label: nil, caption: nil, id: nil, **options)
        @view = view
        @source = source.to_s
        @language = language
        @lines = lines
        @wrap = wrap
        @max_height = max_height
        @copy = copy
        @caption = caption.presence
        @label = label || @caption || I18n.t("unmagic.components.code_view.label", default: "Code")
        @id = id || "unmagic_code_view_#{SecureRandom.hex(4)}"
        @options = options
      end

      def render
        classes = view.class_names("UnmagicCodeView", {
          "UnmagicCodeView--lines" => @lines,
          "UnmagicCodeView--nowrap" => !@wrap,
          "UnmagicCodeView--copy" => @copy && !@caption,
          "UnmagicCodeView--captioned" => @caption
        }, @options[:class])

        tag.div(**@options, id: @id, class: classes, style: style) do
          @caption ? safe_join([ header, pre ]) : safe_join([ pre, (copy if @copy) ].compact)
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def code_id = "#{@id}_code"

      # The height is a knob rather than a class, so a container can set it for
      # every code view inside it (a tool payload does) and an instance can still
      # name its own. The gutter is sized from the longest line number, so a
      # block past 999 lines still lines up; never narrower than three digits.
      def style
        knobs = []
        knobs << "--unmagic-code-view-max-height: #{@max_height}" if @max_height
        knobs << "--unmagic-code-view-digits: #{digits}" if @lines

        [ @options[:style], *knobs ].compact.join("; ").presence
      end

      def digits = [ lines.length.to_s.length, 3 ].max

      def lines
        @lines_of_source ||= Components.configuration.highlight.call(@source, @language)
      end

      # A block that can scroll is focusable and named, so a keyboard can scroll
      # it; one that only wraps isn't, since it would be a tab stop for nothing.
      def pre
        attributes = scrollable? ? { tabindex: 0, role: "region", "aria-label": @label } : {}

        tag.pre(class: "UnmagicCodeView__pre", **attributes) do
          tag.code(body, id: code_id, class: view.class_names("UnmagicCodeView__code", language_class))
        end
      end

      def scrollable? = @max_height.present? || !@wrap

      def language_class
        lexer = Highlight.lexer_for(@language)
        "language-#{lexer.tag}" unless lexer.is_a?(Rouge::Lexers::PlainText) && @language.blank?
      end

      # Each line ends with its own newline inside its span, so a copy of the
      # <code>'s text keeps the line breaks and leaves the numbers, which are
      # drawn by CSS, behind.
      def body
        if @lines
          safe_join(lines.map { |line| tag.span(line + "\n", class: "UnmagicCodeView__line") })
        else
          safe_join(lines, "\n")
        end
      end

      def copy
        tag.div(view.copy_button(from: code_id), class: "UnmagicCodeView__copy")
      end

      # A captioned block names what it holds (a language, a file) above the code,
      # with the copy button beside the name rather than floating over the first line.
      def header
        tag.div(class: "UnmagicCodeView__header") do
          safe_join [ tag.span(@caption, class: "UnmagicCodeView__caption"), (view.copy_button(from: code_id) if @copy) ].compact
        end
      end
    end
  end
end
