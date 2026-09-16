# frozen_string_literal: true

RSpec.describe "elapsed clocks and streamed Markdown" do
  let(:view) { build_view }

  describe Unmagic::Components::Duration do
    it "says a stretch of time the way somebody would" do
      expect([ 0.64, 0, 2, 59.4, 185, 3842 ].map { |seconds| described_class.format(seconds) })
        .to eq([ "640ms", "0s", "2s", "59s", "3m 5s", "1h 4m 2s" ])
    end

    it "has nothing to say about nil" do
      expect(described_class.format(nil)).to be_nil
    end
  end

  describe "#elapsed_tag" do
    before { allow(Time).to receive(:current).and_return(Time.utc(2026, 9, 16, 12)) }

    it "counts up from a time, rendering the reading the element keeps moving" do
      element = html(view.elapsed_tag(Time.current - 185.4, class: "extra")).at("unmagic-elapsed")

      expect(element.text).to eq("3m 5s")
      expect(element["since"]).to eq((Time.current - 185.4).utc.iso8601(3))
      expect(element["until"]).to be_nil
      expect(element["class"]).to eq("UnmagicElapsed extra")
      expect(element["title"]).to be_present
    end

    it "counts down to a time, stopping at zero" do
      expect(html(view.elapsed_tag(Time.current + 41.2, direction: :down)).at("unmagic-elapsed").text).to eq("42s")
      past = html(view.elapsed_tag(Time.current - 5, direction: :down)).at("unmagic-elapsed")
      expect([ past.text, past["until"].present? ]).to eq([ "0s", true ])
    end

    it "renders an em dash for no time" do
      expect(view.elapsed_tag(nil)).to eq("—")
    end

    it "rejects an unknown direction" do
      expect { view.elapsed_tag(Time.current, direction: :sideways) }
        .to raise_error(ArgumentError, /unknown elapsed_tag direction :sideways/)
    end
  end

  describe "#streaming_markdown_tag" do
    it "renders the host's HTML inside the element, unescaped" do
      element = html(view.streaming_markdown_tag("<p>Hi</p>".html_safe, id: "reply_content", class: "extra"))
        .at("unmagic-streaming-markdown#reply_content")

      expect(element.at("p").text).to eq("Hi")
      expect(element["class"]).to eq("UnmagicStreamingMarkdown extra")
      expect(element["aria-busy"]).to be_nil
      expect(element.key?("final")).to be(false)
    end

    it "is busy only while streaming, and never once final" do
      streaming = html(view.streaming_markdown_tag(id: "a", streaming: true)).at("unmagic-streaming-markdown")
      expect(streaming["aria-busy"]).to eq("true")
      expect(streaming.children).to be_empty

      final = html(view.streaming_markdown_tag("x", id: "b", streaming: true, final: true)).at("unmagic-streaming-markdown")
      expect(final.key?("final")).to be(true)
      expect(final["aria-busy"]).to be_nil
    end

    it "needs an id to stream into" do
      expect { view.streaming_markdown_tag(id: nil) }.to raise_error(ArgumentError, /needs an id/)
    end
  end

  describe "turbo_stream.stream_markdown" do
    it "targets the element with the whole render in a template" do
      stream = html(view.turbo_stream.stream_markdown("reply_content", "<p>So far</p>".html_safe)).at("turbo-stream")

      expect([ stream["action"], stream["target"] ]).to eq([ "stream_markdown", "reply_content" ])
      expect(stream.at("template").inner_html).to include("<p>So far</p>")
    end
  end
end
