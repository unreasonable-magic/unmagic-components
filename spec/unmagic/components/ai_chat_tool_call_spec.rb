# frozen_string_literal: true

RSpec.describe "AI chat tool calls and payloads" do
  let(:view) { build_view }

  describe "#ai_chat_tool_call" do
    it "renders a native fold: a summary row, payload figures inside, the result after" do
      call = html(view.ai_chat_tool_call(name: "search_messages", state: :done, id: "call_1", class: "extra") do |tool|
        tool.summary "car seat"
        tool.timing duration: 1.24
        tool.asked({ query: "car seat" })
        tool.answered "No matches"
        tool.made { view.link_to "Open", "/result" }
      end).at("unmagic-tool-call#call_1")

      expect(call["class"]).to eq("extra")
      expect(call["data-ai-chat-timeline"]).to eq("row")
      expect(call["state"]).to eq("done")
      expect(call["aria-busy"]).to be_nil
      expect(call.css("> *").map(&:name)).to eq(%w[details div])
      expect(call.css("> details > *").map(&:name)).to eq(%w[summary figure figure])
      expect(call.css("> details > summary > *").map(&:name)).to eq(%w[span code span time])
      expect(call.at("> details > summary > code").text).to eq("search_messages")
      expect(call.at("> details > summary > span:not([data-tool-call-glyph])").text).to eq("car seat")
      expect(call.at("> details > summary > time")["datetime"]).to eq("PT1.24S")
      expect(call.at("> details > summary > time").text).to eq("Took1s")
      expect(call.css("> details > figure > figcaption").map(&:text)).to eq(%w[Asked Answered])
      expect(call.at("> div > a")["href"]).to eq("/result")
      expect(call.css("[class*='UnmagicAIChatToolCall'], [data-part], [id]").map { |node| node["id"] || node["class"] })
        .to all(start_with("unmagic_code_view"))
    end

    it "seeds the glyph with the state it drew, its status word and the done icon for later" do
      call = html(view.ai_chat_tool_call(name: "render", state: :running, icon: :folder)).at("unmagic-tool-call")
      glyph = call.at("> details > summary > [data-tool-call-glyph]")

      expect(call["aria-busy"]).to eq("true")
      expect(glyph["data-tool-call-glyph"]).to eq("running")
      expect(glyph.css("> *").map(&:name)).to eq(%w[svg template span])
      expect(glyph.at("> svg")["class"]).to include("UnmagicAIChatSpinner")
      expect(glyph.at("> svg")["aria-hidden"]).to eq("true")
      expect(glyph.at("> template svg")["data-unmagic-icon"]).to end_with("/folder")
      expect(glyph.at("> span.UnmagicVisuallyHidden").text).to eq("Running")

      done = html(view.ai_chat_tool_call(name: "render", state: :done, icon: :folder)).at("[data-tool-call-glyph]")
      expect(done.at("> svg")["data-unmagic-icon"]).to end_with("/folder")
      expect(done.at("template")).to be_nil
    end

    it "renders the readings as the elements they are, and progress as an output" do
      started = Time.current - 7
      call = html(view.ai_chat_tool_call(name: "render", state: :running, id: "call_2") do |tool|
        tool.timing started_at: started, duration: 0
        tool.failures 2
        tool.progress "Still working"
      end).at("unmagic-tool-call")
      summary = call.at("> details > summary")

      expect(summary.css("> *").map(&:name)).to eq(%w[span code data unmagic-elapsed time output])
      expect(summary.at("> data")["value"]).to eq("2")
      expect(summary.at("> data").text).to eq("Partly failed2 failed")
      expect(summary.at("> unmagic-elapsed")["since"]).to eq(started.utc.iso8601(3))
      expect(summary.at("> unmagic-elapsed").text).to eq("Running for7s")
      expect(summary.at("> unmagic-elapsed").children.last.text?).to be(true)
      expect(summary.at("> time").text).to eq("Took0s")
      expect(summary.at("> output").text).to eq("Still working")
    end

    it "always renders the fold, open when asked, and can stand outside the timeline" do
      call = html(view.ai_chat_tool_call(name: "ping", state: :queued, timeline: false, open: true)).at("unmagic-tool-call")

      expect(call.css("> details > *").map(&:name)).to eq(%w[summary])
      expect(call.at("> details").key?("open")).to be(true)
      expect(call["data-ai-chat-timeline"]).to be_nil
      expect(html(view.ai_chat_tool_call(name: "ping", state: :queued)).at("details").key?("open")).to be(false)
    end

    it "escapes the name and supplies every state's translated word" do
      I18n.backend.store_translations(:en, unmagic: { components: { ai_chat: { tool_call: { running: "En cours" } } } })
      call = html(view.ai_chat_tool_call(name: "<search>", state: :queued)).at("unmagic-tool-call")

      expect(call.at("summary > code").text).to eq("<search>")
      expect(call.at("search")).to be_nil
      expect(call["label-running"]).to eq("En cours")
      expect(call["label-done"]).to eq("Done")
    ensure
      I18n.backend.reload!
    end

    it "rejects an unknown state" do
      expect { view.ai_chat_tool_call(name: "x", state: :lost) }.to raise_error(ArgumentError, /state/)
    end
  end

  describe "#ai_chat_payload" do
    it "is a captioned figure over a scrollable region, laying structured data out as JSON" do
      figure = html(view.ai_chat_payload({ "query" => "cats", "limit" => 5 }, label: "Asked", class: "extra")).at("figure")

      expect(figure["class"]).to eq("extra")
      expect(figure.css("> *").map(&:name)).to eq(%w[figcaption div])
      expect(figure.at("> figcaption").text).to eq("Asked")
      region = figure.at("> div")
      expect([ region["tabindex"], region["role"], region["aria-label"] ]).to eq([ "0", "region", "Asked" ])
      expect(region.at("pre > code")["class"]).to include("language-json")
      expect(region.text).to eq(%({\n  "query": "cats",\n  "limit": 5\n}))
    end

    it "parses a JSON string, and leaves other text as text" do
      expect(html(view.ai_chat_payload("[1,2]")).at("code")["class"]).to include("language-json")

      plain = html(view.ai_chat_payload("<oops> not json")).at("code")
      expect([ plain["class"], plain.text ]).to eq([ "UnmagicCodeView__code language-plaintext", "<oops> not json" ])
    end

    it "takes the language it's given for text" do
      expect(html(view.ai_chat_payload("a\nb", language: :ruby)).at("code")["class"]).to include("language-ruby")
    end

    it "renders nothing for no payload, and no caption without a label" do
      expect(view.ai_chat_payload(nil)).to be_blank
      expect(html(view.ai_chat_payload("x")).at("figcaption")).to be_nil
      expect(html(view.ai_chat_payload("x")).at("[role=region]")["aria-label"]).to eq("Payload")
    end

    it "shows the duration as a time, and a copy button when asked" do
      caption = html(view.ai_chat_payload({ a: 1 }, label: "Answered", duration: 0.048, copy: true)).at("figcaption")

      expect(caption.at("> time")["datetime"]).to eq("PT0.048S")
      expect(caption.at("> time").text).to eq("Took48ms")
      expect(caption.at("> unmagic-clipboard")["value"]).to eq(%({\n  "a": 1\n}))
    end
  end

  describe "turbo_stream.ai_chat_tool_call" do
    let(:streams) { Turbo::Streams::TagBuilder.new(view) }

    it "addresses each part by what it is under the call's id, and the state through its own action" do
      markup = html(streams.ai_chat_tool_call("call_9") do |tool|
        tool.progress "Frame 13 of 40"
        tool.answered "done", duration: 0.5
        tool.made { view.link_to "Open", "/x" }
        tool.state :done
      end)
      actions = markup.css("turbo-stream")

      expect(actions.map { |action| [ action["action"], action["target"] || action["targets"] ] }).to eq([
        [ "update", "#call_9 > details > summary > output" ],
        [ "append", "#call_9 > details" ],
        [ "append", "call_9" ],
        [ "tool_call_state", "#call_9" ]
      ])
      expect(actions[0].at("template").text).to eq("Frame 13 of 40")
      expect(actions[1].at("template > figure > figcaption").children.first.text).to eq("Answered")
      expect(actions[1].at("template > figure > figcaption > time")["datetime"]).to eq("PT0.5S")
      expect(actions[2].at("template > div > a")["href"]).to eq("/x")
      expect(actions[3]["state"]).to eq("done")
    end

    it "sends nothing for an absent payload, and rejects an unknown state" do
      expect(html(streams.ai_chat_tool_call("call_9") { |tool| tool.asked nil }).css("turbo-stream")).to be_empty
      expect { streams.ai_chat_tool_call("call_9") { |tool| tool.state :lost } }.to raise_error(ArgumentError, /state/)
    end
  end
end
