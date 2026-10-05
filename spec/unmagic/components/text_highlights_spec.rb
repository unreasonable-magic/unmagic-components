# frozen_string_literal: true

RSpec.describe "Text highlights" do
  let(:view) { build_view }

  def marks(markup)
    html(markup).css("mark").map { |mark| [ mark.text, mark["class"], mark["data-highlight"] ] }
  end

  describe "#text_highlights" do
    it "marks a passage of plain text, escaping the rest" do
      doc = html(view.text_highlights("<b>Hi</b>, I'll pick them up at 5.", "pick them up"))

      expect(doc.css("b")).to be_empty
      expect(doc.text).to eq("<b>Hi</b>, I'll pick them up at 5.")
      expect(marks(doc.to_html)).to eq([ [ "pick them up", "UnmagicMark UnmagicMark--yellow", "0" ] ])
    end

    it "forgives case, whitespace, curly quotes, dashes and ellipses" do
      text = "I can’t  do\nFriday — sorry… “really”"
      markup = view.text_highlights(text, [ "i can't do friday", { text: "- sorry...", color: :red }, '"Really"' ])

      expect(marks(markup)).to eq([
        [ "I can’t  do\nFriday", "UnmagicMark UnmagicMark--yellow", "0" ],
        [ "— sorry…", "UnmagicMark UnmagicMark--red", "1" ],
        [ "“really”", "UnmagicMark UnmagicMark--yellow", "2" ]
      ])
    end

    it "marks the first place a highlight matches" do
      expect(html(view.text_highlights("no, no and no", "no")).css("mark").length).to eq(1)
      expect(marks(view.text_highlights("no, no and no", "and no"))).to eq([ [ "and no", "UnmagicMark UnmagicMark--yellow", "0" ] ])
    end

    it "marks a range from one quote to the first of the other after it" do
      text = "Bring the bag. Rent is due on the first, into the account. The bond is held."

      expect(marks(view.text_highlights(text, { from: "rent is due", to: "account." })))
        .to eq([ [ "Rent is due on the first, into the account.", "UnmagicMark UnmagicMark--yellow", "0" ] ])
      expect(view.text_highlights(text, { from: "the bond", to: "Rent" })).not_to include("<mark")
    end

    it "lets a later highlight win where two overlap" do
      markup = view.text_highlights("one two three", [ "one two three", { text: "two", color: :blue } ])

      expect(marks(markup)).to eq([
        [ "one ", "UnmagicMark UnmagicMark--yellow", "0" ],
        [ "two", "UnmagicMark UnmagicMark--blue", "1" ],
        [ " three", "UnmagicMark UnmagicMark--yellow", "0" ]
      ])
    end

    it "keeps markup, and runs a highlight across its tags and paragraphs" do
      markup = view.text_highlights([ { from: "the new", to: "next week" }, { text: "page", color: :green } ]) do
        '<p>See the new <a href="/b">booking page</a>.</p><p>From next week &amp; on.</p>'.html_safe
      end
      doc = html(markup)

      expect(doc.at("a[href='/b']")).not_to be_nil
      expect(doc.css("p").length).to eq(2)
      expect(marks(markup)).to eq([
        [ "the new ", "UnmagicMark UnmagicMark--yellow", "0" ],
        [ "booking ", "UnmagicMark UnmagicMark--yellow", "0" ],
        [ "page", "UnmagicMark UnmagicMark--green", "1" ],
        [ ".", "UnmagicMark UnmagicMark--yellow", "0" ],
        [ "From next week", "UnmagicMark UnmagicMark--yellow", "0" ]
      ])
      expect(doc.css("p").last.text).to eq("From next week & on.")
    end

    it "returns the content as it was without highlights, or when nothing matches" do
      expect(view.text_highlights("<i>x</i>", [])).to eq("&lt;i&gt;x&lt;/i&gt;")
      expect(view.text_highlights("<i>x</i>".html_safe, [])).to eq("<i>x</i>")
      expect(view.text_highlights(nil, "x")).to eq("")
      expect(view.text_highlights("hello", "absent")).to eq("hello")
    end

    it "says which highlights it couldn't find" do
      highlights = Unmagic::Components::TextHighlights.new(view, [ "here", "absent", { from: "here", to: "nope" } ])
      highlights.render("here it is")

      expect(highlights.unmatched.map { |highlight| highlight.text || highlight.from }).to eq([ "absent", "here" ])
    end

    it "raises on an unknown colour or a malformed highlight" do
      expect { view.text_highlights("x", { text: "x", color: :purple }) }
        .to raise_error(ArgumentError, "unknown text_highlights color :purple (expected one of [:yellow, :green, :blue, :pink, :red])")
      expect { view.text_highlights("x", { text: "x", from: "x", to: "y" }) }.to raise_error(ArgumentError, /not both or neither/)
      expect { view.text_highlights("x", { from: "x" }) }.to raise_error(ArgumentError, /needs both from: and to:/)
      expect { view.text_highlights("x", { words: "x" }) }.to raise_error(ArgumentError, /Unknown key: :words/)
      expect { view.text_highlights("x", [ 1 ]) }.to raise_error(ArgumentError, /a String or a Hash/)
    end
  end

  describe "message highlights" do
    it "marks passages of the body" do
      markup = view.message(own: true) do |m|
        m.highlight "can't do Friday", color: :red
        m.highlight from: "pick them", to: "at 5"
        "I can’t do Friday. I'll pick them up at 5."
      end
      body = html(markup).at(".UnmagicMessage__body")

      expect(body.text).to eq("I can’t do Friday. I'll pick them up at 5.")
      expect(marks(body.to_html)).to eq([
        [ "can’t do Friday", "UnmagicMark UnmagicMark--red", "0" ],
        [ "pick them up at 5", "UnmagicMark UnmagicMark--yellow", "1" ]
      ])
    end

    it "validates a highlight's colour" do
      expect { view.message("x") { |m| m.highlight "x", color: :teal } }.to raise_error(ArgumentError, /unknown text_highlights color :teal/)
    end
  end
end
