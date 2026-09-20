# frozen_string_literal: true

require "rouge"
require "erb"

module Unmagic
  module Components
    # Colours source with Rouge, a line at a time. See ActionViewHelpers#code_view
    # and Configuration#highlight.
    #
    # The spans are built here rather than through Rouge's own HTML formatter so
    # escaping stays Rails': what's highlighted is a file somebody else wrote or a
    # payload a model made up, and neither is markup to be trusted. Each token is
    # cut at its newlines, so a string or comment that runs across lines colours
    # every line it touches and a line number can sit in front of each one.
    module Highlight
      class << self
        # One html_safe string per line of the source. A trailing newline ends the
        # last line rather than starting an empty one.
        def lines(source, language)
          lines = [ +"" ]

          lexer_for(language).lex(source.to_s).each do |token, value|
            value.split("\n", -1).each_with_index do |piece, index|
              lines << +"" if index.positive?
              lines.last << span(token, piece) unless piece.empty?
            end
          end

          lines.pop if lines.length > 1 && lines.last.empty?
          lines.map(&:html_safe)
        end

        # The lexer for a language named as a symbol or string ("json", :ruby, or
        # an alias Rouge knows), a lexer class, or an instance. Anything Rouge
        # doesn't know, and no language at all, is plain text.
        def lexer_for(language)
          case language
          when Rouge::Lexer then language
          when Class then language.new
          when nil, "" then Rouge::Lexers::PlainText.new
          else Rouge::Lexer.find_fancy(language.to_s) || Rouge::Lexers::PlainText.new
          end
        end

        private

        def span(token, value)
          escaped = ERB::Util.html_escape(value)
          name = token.shortname

          name.empty? ? escaped : "<span class=\"#{name}\">#{escaped}</span>"
        end
      end
    end
  end
end
