# frozen_string_literal: true

RSpec.describe "AI chat tool calls and payloads" do
  let(:view) { build_view }

  describe "#ai_chat_tool_call" do
    it "renders a timeline row with a disclosure of what was asked and answered" do
      row = html(view.ai_chat_tool_call(name: "search_messages", state: :done, id: "call_1", class: "extra") do |tool|
        tool.summary "car seat"
        tool.timing duration: 1.24
        tool.asked({ query: "car seat" })
        tool.answered "No matches"
      end).at("div#call_1")

      expect(row["class"]).to eq("UnmagicAIChatToolCall UnmagicAIChatToolCall--done extra")
      expect(row["data-ai-chat-timeline"]).to eq("row")
      expect(row.at("> .UnmagicAIChatToolCall__join")["aria-hidden"]).to eq("true")

      summary = row.at("details.UnmagicAIChatToolCall__disclosure > summary.UnmagicAIChatToolCall__row")
      expect(summary.at("code.UnmagicAIChatToolCall__name").text).to eq("search_messages")
      expect(summary.at(".UnmagicAIChatToolCall__summary").text).to eq("car seat")
      expect(summary.at(".UnmagicAIChatToolCall__glyph .UnmagicVisuallyHidden").text).to eq("Done")
      expect(summary.at(".UnmagicAIChatToolCall__reading").text).to eq("Took1s")
      expect(summary.at(".UnmagicAIChatChevron")).not_to be_nil

      body = row.at(".UnmagicAIChatToolCall__body")
      expect(body.at("> .UnmagicAIChatToolCall__rail")).not_to be_nil
      expect(body.css(".UnmagicAIChatPayload__label").map(&:text)).to eq(%w[Asked Answered])
    end

    it "has no disclosure when there's nothing to disclose" do
      row = html(view.ai_chat_tool_call(name: "ping", state: :queued)).at(".UnmagicAIChatToolCall")
      expect(row.at("details")).to be_nil
      expect(row.at("div.UnmagicAIChatToolCall__row .UnmagicAIChatChevron")).to be_nil
    end

    it "is busy while running, with a live clock and a progress line to replace" do
      started = Time.current - 7
      row = html(view.ai_chat_tool_call(name: "render", state: :running, id: "call_2") do |tool|
        tool.timing started_at: started
        tool.progress "Frame 12 of 40"
      end).at("#call_2")

      expect(row["aria-busy"]).to eq("true")
      expect(row.at(".UnmagicAIChatToolCall__glyph .UnmagicAIChatSpinner")).not_to be_nil
      expect(row.at("unmagic-elapsed")["since"]).to eq(started.utc.iso8601(3))
      expect(row.at("#call_2_progress").text).to eq("Frame 12 of 40")
    end

    it "leads a done call with what it was about, and only a done call" do
      done = html(view.ai_chat_tool_call(name: "a", state: :done, icon: :folder)).at("svg")
      expect(done["data-unmagic-icon"]).to end_with("/folder")

      waiting = html(view.ai_chat_tool_call(name: "a", state: :waiting, icon: :folder)).at("svg")
      expect(waiting["data-unmagic-icon"]).to end_with("/circle-question-mark")
    end

    it "counts partial failures, but not on a call that failed outright" do
      partial = html(view.ai_chat_tool_call(name: "a", state: :done) { |tool| tool.failures 3 })
      expect(partial.at(".UnmagicAIChatToolCall__reading--warn").text).to eq("Partly failed3 failed")

      failed = html(view.ai_chat_tool_call(name: "a", state: :failed) { |tool| tool.failures 3 })
      expect(failed.at(".UnmagicAIChatToolCall__reading--warn")).to be_nil
      expect(html(view.ai_chat_tool_call(name: "a", state: :done) { |tool| tool.failures 0 }).at(".UnmagicAIChatToolCall__readings")).to be_nil
    end

    it "keeps what a call made outside the fold" do
      row = html(view.ai_chat_tool_call(name: "a", state: :done) do |tool|
        tool.asked({ a: 1 })
        tool.made { "<img alt='render'>".html_safe }
      end).at(".UnmagicAIChatToolCall")

      made = row.at("> .UnmagicAIChatToolCall__made")
      expect(made.at("img")).not_to be_nil
      expect(made.at(".UnmagicAIChatToolCall__rail")).not_to be_nil
    end

    it "can stand outside the timeline, and open" do
      row = html(view.ai_chat_tool_call(name: "a", state: :done, timeline: false, open: true) { |tool| tool.asked "x" })
      expect(row.at(".UnmagicAIChatToolCall")["data-ai-chat-timeline"]).to be_nil
      expect(row.at(".UnmagicAIChatToolCall__join")).to be_nil
      expect(row.at("details").key?("open")).to be(true)
    end

    it "rejects an unknown state" do
      expect { view.ai_chat_tool_call(name: "a", state: :dozing) }
        .to raise_error(ArgumentError, /unknown ai_chat_tool_call state :dozing/)
    end
  end

  describe "#ai_chat_payload" do
    it "lays structured data out a key to a line, as JSON" do
      payload = html(view.ai_chat_payload({ "query" => "cats", "limit" => 5 }, label: "Asked", class: "extra"))
      root = payload.at(".UnmagicAIChatPayload")

      expect(root["class"]).to eq("UnmagicAIChatPayload extra")
      code = root.at(".UnmagicAIChatPayload__code")
      expect([ code["tabindex"], code["role"], code["aria-label"] ]).to eq([ "0", "region", "Asked" ])
      expect(code.at("pre > code")["class"]).to include("language-json")
      expect(code.text).to eq(%({\n  "query": "cats",\n  "limit": 5\n}))
    end

    it "parses a JSON string, and leaves other text as text" do
      expect(html(view.ai_chat_payload('[1,2]')).at("code")["class"]).to include("language-json")

      plain = html(view.ai_chat_payload("<oops> not json")).at("code")
      expect([ plain["class"], plain.text ]).to eq([ "UnmagicCodeView__code language-plaintext", "<oops> not json" ])
    end

    it "takes the language it's given for text" do
      expect(html(view.ai_chat_payload("a\nb", language: :ruby)).at("code")["class"]).to include("language-ruby")
    end

    it "renders nothing for no payload, and no head without a label" do
      expect(view.ai_chat_payload(nil)).to be_blank
      expect(html(view.ai_chat_payload("x")).at(".UnmagicAIChatPayload__head")).to be_nil
      expect(html(view.ai_chat_payload("x")).at(".UnmagicAIChatPayload__code")["aria-label"]).to eq("Payload")
    end

    it "shows the duration and a copy button when asked" do
      head = html(view.ai_chat_payload({ a: 1 }, label: "Answered", duration: 0.048, copy: true)).at(".UnmagicAIChatPayload__head")
      expect(head.at(".UnmagicAIChatPayload__timing").text).to eq("Took48ms")
      expect(head.at("unmagic-clipboard")["value"]).to eq(%({\n  "a": 1\n}))
    end

    it "renders through the code_block seam" do
      calls = []
      Unmagic::Components.configure do |config|
        config.code_block = lambda do |view, source, language|
          calls << [ source, language ]
          view.tag.pre("highlighted", class: "hl")
        end
      end

      expect(html(view.ai_chat_payload({ a: 1 })).at("pre.hl").text).to eq("highlighted")
      expect(calls).to eq([ [ %({\n  "a": 1\n}), :json ] ])
    end
  end
end
