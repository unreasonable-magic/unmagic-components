# frozen_string_literal: true

module Unmagic
  module Components
    # A host's rendered, sanitised Markdown, finished for reading. Each code block
    # (a <pre> holding a <code>) is redrawn through config.prose_code_block with
    # the language its fence named, so it's coloured, titled and copyable like any
    # other code the gem draws. See ActionViewHelpers#prose.
    class Prose
      def initialize(view, html)
        @view = view
        @html = html.to_s
      end

      def render
        return "".html_safe if @html.blank? # rubocop:disable Rails/OutputSafety -- empty

        fragment = parse(@html)
        fragment.css("pre").each { |pre| redraw(pre) }
        fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety -- re-serialised by Nokogiri, which escapes the text it holds
      end

      private

      attr_reader :view

      def redraw(pre)
        code = pre.element_children.first
        return unless pre.element_children.one? && code.name == "code"

        block = Components.configuration.prose_code_block.call(view, code.text.chomp, language(pre, code))
        pre.replace(parse(view.tag.div(block, class: "UnmagicProse__code not-prose").to_s))
      end

      # CommonMark renders a fence's info string as <pre lang="ruby"> (comrak) or
      # <code class="language-ruby"> (most others).
      def language(pre, code)
        pre["lang"].presence || code["class"].to_s[/(?:\A|\s)language-(\S+)/, 1]
      end

      def parse(content)
        if defined?(Nokogiri::HTML5)
          Nokogiri::HTML5.fragment(content)
        else
          Nokogiri::HTML::DocumentFragment.parse(content)
        end
      end
    end
  end
end
