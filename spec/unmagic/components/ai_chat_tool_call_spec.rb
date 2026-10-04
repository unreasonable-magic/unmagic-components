# frozen_string_literal: true

RSpec.describe "AI chat tool calls and payloads" do
  let(:view) { build_view }

  describe "#ai_chat_tool_call" do
    it "renders readable timeline parts for the element to compose" do
      call = html(view.ai_chat_tool_call(name: "search_messages", state: :done, id: "call_1", class: "extra") do |tool|
        tool.summary "car seat"
        tool.timing duration: 1.24
        tool.asked({ query: "car seat" })
        tool.answered "No matches"
      end).at("unmagic-tool-call#call_1")

      expect(call["class"]).to eq("UnmagicAIChatToolCall UnmagicAIChatToolCall--done extra")
      expect(call["data-ai-chat-timeline"]).to eq("row")
      expect(call["state"]).to eq("done")
      expect(call["aria-busy"]).to be_nil
      expect(call.at('[data-part="name"]').text).to eq("search_messages")
      expect(call.at('[data-part="summary"]').text).to eq("car seat")
      expect(call.at('[data-part="status"]').text).to eq("Done")
      expect(call.at('[data-part="duration"]').text).to eq("Took1s")
      expect(call.css('> [data-part="payload"] .UnmagicAIChatPayload__label').map(&:text)).to eq(%w[Asked Answered])
      expect(call.at("details, .UnmagicAIChatToolCall__join, .UnmagicAIChatToolCall__rail")).to be_nil
    end

    it "supplies a live clock and stable progress stream target" do
      started = Time.current - 7
      call = html(view.ai_chat_tool_call(name: "render", state: :running, id: "call_2") do |tool|
        tool.timing started_at: started
        tool.progress "Frame 12 of 40"
      end).at("unmagic-tool-call#call_2")

      expect(call["aria-busy"]).to eq("true")
      expect(call.at('[data-part="status"]').text).to eq("Running")
      expect(call.at("unmagic-elapsed")["since"]).to eq(started.utc.iso8601(3))
      expect(call.at('#call_2_progress[data-part="progress"]').text).to eq("Frame 12 of 40")
    end

    it "omits readings that have no supplied value" do
      call = html(view.ai_chat_tool_call(name: "a", state: :done) do |tool|
        tool.failures 0
        tool.timing
      end).at("unmagic-tool-call")
      expect(call.at('[data-part="readings"]')).to be_nil
    end

    it "rejects an unknown state" do
      expect { view.ai_chat_tool_call(name: "a", state: :dozing) }
        .to raise_error(ArgumentError, /unknown ai_chat_tool_call state :dozing/)
    end

    it "renders readable element parts by default without server-generated disclosure or decoration" do
      call = html(view.ai_chat_tool_call(name: "<search>", state: :running, id: "element_call",
        open: true, class: "extra", data: { custom: "kept" }) do |tool|
        tool.asked nil
        tool.answered ""
        tool.progress "Still working"
        tool.made { view.link_to("Result", "/result") }
      end).at("unmagic-tool-call")

      expect(call["id"]).to eq("element_call")
      expect(call["class"]).to include("extra")
      expect(call["data-custom"]).to eq("kept")
      expect(call["data-ai-chat-timeline"]).to eq("row")
      expect(call["aria-busy"]).to eq("true")
      expect(call.key?("open")).to be(true)
      expect(call.at('[data-part="row"] code').text).to eq("<search>")
      expect(call.at("search")).to be_nil
      expect(call.at("#element_call_progress").text).to eq("Still working")
      expect(call.css('> [data-part="payload"]').size).to eq(1)
      expect(call.at('> [data-part="result"] a')["href"]).to eq("/result")
      expect(call.at("details, .UnmagicAIChatToolCall__join, .UnmagicAIChatToolCall__rail")).to be_nil
    end

    it "keeps calls without payloads readable and can opt out of the timeline" do
      call = html(view.ai_chat_tool_call(name: "ping", state: :done, timeline: false))
        .at("unmagic-tool-call")
      expect(call.at('[data-part="row"]').text).to include("ping")
      expect(call.at('[data-part="payload"]')).to be_nil
      expect(call["data-ai-chat-timeline"]).to be_nil
      expect(call.key?("open")).to be(false)
    end

    it "supplies all state-independent content for reactive element updates" do
      call = html(view.ai_chat_tool_call(name: "search", state: :failed, icon: :folder) do |tool|
        tool.progress "Looking"
        tool.failures 2
        tool.timing started_at: Time.current, duration: 0
      end).at("unmagic-tool-call")
      expect(call["state"]).to eq("failed")
      expect(call["label-running"]).to eq("Running")
      expect(call.at('[data-part="progress"]').text).to eq("Looking")
      expect(call.at('[data-part="failures"]').text).to include("2 failed")
      expect(call.at('[data-part="elapsed"] unmagic-elapsed')).not_to be_nil
      expect(call.at('[data-part="duration"]').text).to eq("Took0s")
      expect(call.at('template[data-part="success-icon"] svg')["data-unmagic-icon"]).to end_with("/folder")
      expect(call.at(".UnmagicAIChatToolCall__glyph")).to be_nil
    end

    it "supplies translated labels for future states" do
      I18n.backend.store_translations(:en, unmagic: { components: { ai_chat: { tool_call: { running: "En cours" } } } })
      I18n.with_locale(:en) do
        call = html(view.ai_chat_tool_call(name: "search", state: :queued)).at("unmagic-tool-call")
        expect(call["label-running"]).to eq("En cours")
      end
    ensure
      I18n.backend.reload!
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
