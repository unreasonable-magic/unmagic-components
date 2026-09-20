# frozen_string_literal: true

RSpec.describe "code view" do
  let(:view) { build_view }

  describe Unmagic::Components::Highlight do
    it "colours a line at a time, cutting tokens at newlines" do
      lines = described_class.lines(%(x = "a\nb" # hi\n), :ruby)

      expect(lines.length).to eq(2)
      expect(lines[0]).to eq(%(<span class="n">x</span> <span class="o">=</span> <span class="s2">&quot;a</span>))
      expect(lines[1]).to eq(%(<span class="s2">b&quot;</span> <span class="c1"># hi</span>))
      expect(lines).to all(be_html_safe)
    end

    it "escapes the source rather than trusting it" do
      expect(described_class.lines("<b>&</b>", nil)).to eq([ "&lt;b&gt;&amp;&lt;/b&gt;" ])
    end

    it "keeps empty lines and drops only the trailing newline" do
      expect(described_class.lines("a\n\nb\n", :plaintext)).to eq([ "a", "", "b" ])
      expect(described_class.lines("", :plaintext)).to eq([ "" ])
    end

    it "finds a lexer by name, class or instance, and falls back to plain text" do
      expect(described_class.lexer_for("json").tag).to eq("json")
      expect(described_class.lexer_for(:ruby).tag).to eq("ruby")
      expect(described_class.lexer_for(Rouge::Lexers::ERB).tag).to eq("erb")
      expect(described_class.lexer_for(Rouge::Lexers::Shell.new).tag).to eq("shell")
      expect(described_class.lexer_for("no-such-language").tag).to eq("plaintext")
      expect(described_class.lexer_for(nil).tag).to eq("plaintext")
    end
  end

  describe "#code_view" do
    it "renders coloured source in a pre with a copy button" do
      doc = html(view.code_view(%({"a": 1}), language: :json, id: "payload"))
      root = doc.at("div.UnmagicCodeView#payload")

      expect(root["class"]).to eq("UnmagicCodeView UnmagicCodeView--copy")
      code = root.at("pre.UnmagicCodeView__pre > code#payload_code")
      expect(code["class"]).to eq("UnmagicCodeView__code language-json")
      expect(code.css("span").map { |span| [ span["class"], span.text ] }).to include([ "nl", %("a") ], [ "mi", "1" ])
      expect(code.text).to eq(%({"a": 1}))
      expect(root.at(".UnmagicCodeView__copy unmagic-clipboard")["for"]).to eq("payload_code")
      expect(root.at("pre")["tabindex"]).to be_nil
    end

    it "numbers lines with one block per line, each keeping its newline for a copy" do
      code = html(view.code_view("a\n\nb", lines: true)).at("code")

      lines = code.css("span.UnmagicCodeView__line")
      expect(lines.map(&:text)).to eq([ "a\n", "\n", "b\n" ])
      expect(code.parent.parent["class"]).to include("UnmagicCodeView--lines")
    end

    it "is a focusable, named region when it can scroll" do
      pre = html(view.code_view("x", max_height: "20rem", label: "Backtrace")).at("pre")
      expect([ pre["tabindex"], pre["role"], pre["aria-label"] ]).to eq([ "0", "region", "Backtrace" ])
      expect(pre.parent["style"]).to eq("--unmagic-code-view-max-height: 20rem")

      sideways = html(view.code_view("x", wrap: false)).at("div")
      expect(sideways["class"]).to include("UnmagicCodeView--nowrap")
      expect([ sideways.at("pre")["tabindex"], sideways.at("pre")["aria-label"] ]).to eq([ "0", "Code" ])
    end

    it "drops the copy button and the language class when asked or unknown" do
      doc = html(view.code_view("plain", copy: false, class: "mt-2", style: "color: red", title: "T"))
      root = doc.at("div")

      expect(root["class"]).to eq("UnmagicCodeView mt-2")
      expect(root["style"]).to eq("color: red")
      expect(root["title"]).to eq("T")
      expect(root.at("code")["class"]).to eq("UnmagicCodeView__code")
      expect(root.at("unmagic-clipboard")).to be_nil
    end

    it "takes a block as the source, minus the template's indentation" do
      captured = "\n    {\n      \"a\": \"<b>\"\n    }\n  ".html_safe
      doc = html(view.code_view(language: :json) { captured })

      expect(doc.at("code").text).to eq(%({\n  "a": "<b>"\n}))
      expect(doc.at("code").inner_html).to include("&lt;b&gt;")
    end

    it "colours through the highlight seam" do
      Unmagic::Components.configure do |config|
        config.highlight = ->(source, language) { [ "<b>#{language}: #{source}</b>".html_safe ] }
      end

      expect(html(view.code_view("x", language: :ruby)).at("code b").text).to eq("ruby: x")
    end

    it "is what the code_block seam renders by default" do
      block = html(Unmagic::Components.configuration.code_block.call(view, "y", :json))

      expect(block.at("div.UnmagicCodeView code")["class"]).to eq("UnmagicCodeView__code language-json")
      expect(block.at("unmagic-clipboard")).to be_nil
    end
  end
end
