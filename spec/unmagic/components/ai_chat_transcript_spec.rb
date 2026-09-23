# frozen_string_literal: true

RSpec.describe "AI chat transcripts and messages" do
  let(:view) { build_view }

  describe "#ai_chat" do
    it "renders a polite log inside an autoscroll with a jump-to-latest button" do
      doc = html(view.ai_chat(id: "entries", class: "extra", data: { chat: 1 }) { "<div id='m1'>Hi</div>".html_safe })

      scroll = doc.at("unmagic-autoscroll.UnmagicAutoscroll")
      log = scroll.at("> div#entries")
      expect(log["class"]).to eq("UnmagicAIChat extra")
      expect(log["data-chat"]).to eq("1")
      expect([ log["role"], log["aria-live"], log["aria-relevant"], log["aria-label"] ])
        .to eq([ "log", "polite", "additions", "Conversation" ])
      expect(log.at("#m1").text).to eq("Hi")

      button = scroll.at(".UnmagicAIChat__latest > button[data-autoscroll-latest]")
      expect(button.key?("hidden")).to be(true)
      expect([ button["aria-label"], button["title"] ]).to eq([ "Jump to latest", "Jump to latest" ])
    end

    it "hands the scroller to the autoscroll element" do
      doc = html(view.ai_chat(id: "entries", scroller: "#panel") { "" })
      expect(doc.at("unmagic-autoscroll")["scroller"]).to eq("#panel")
      expect(doc.at("#entries")["scroller"]).to be_nil
    end

    it "renders a bare log when it shouldn't follow, and no button when asked" do
      expect(html(view.ai_chat(id: "a", follow: false) { "" }).at("unmagic-autoscroll")).to be_nil
      expect(html(view.ai_chat(id: "b", scroll_to_latest: false) { "" }).at("button")).to be_nil
    end

    it "shows the welcome only while there are no entries" do
      empty = html(view.ai_chat(id: "entries") do |chat|
        chat.welcome { "Ask me" }
        nil
      end)
      expect(empty.at("#entries > .UnmagicAIChat__welcome").text).to eq("Ask me")

      full = html(view.ai_chat(id: "entries") do |chat|
        chat.welcome "Ask me"
        "<div id='m1'></div>".html_safe
      end)
      expect(full.at(".UnmagicAIChat__welcome")).to be_nil
    end

    it "still renders the log with nothing in it, for broadcasts to land in" do
      expect(html(view.ai_chat(id: "entries")).at("#entries")).not_to be_nil
    end

    it "needs an id" do
      expect { view.ai_chat(id: "") }.to raise_error(ArgumentError, /needs an id/)
    end
  end

  describe "#ai_chat_message" do
    it "renders a user's turn as an own bubble of plain text, built on message" do
      doc = html(view.ai_chat_message(role: :user, id: "m1", class: "extra") { "<b>Hi</b>\nthere" })
      turn = doc.at("article#m1")

      expect(turn["class"]).to eq("UnmagicMessage UnmagicMessage--bubble UnmagicMessage--own UnmagicAIChatMessage UnmagicAIChatMessage--user extra")
      expect(turn.at(".UnmagicMessage__header .UnmagicVisuallyHidden").text).to eq("You said")
      bubble = turn.at(".UnmagicMessage__main > .UnmagicMessage__body")
      expect(bubble.text).to eq("<b>Hi</b>\nthere")
      expect(bubble.at("b")).to be_nil
      expect(bubble["class"]).not_to include("UnmagicProse")
    end

    it "trims a block's surrounding whitespace from the bubble, keeping the escaping" do
      bubble = html(view.ai_chat_message(role: :user) { "\n    #{ERB::Util.html_escape("<b>Hi</b>")}\n  ".html_safe })
        .at(".UnmagicMessage__body")
      expect(bubble.inner_html).to eq("&lt;b&gt;Hi&lt;/b&gt;")
    end

    it "renders an assistant's turn as a row of prose inside the streaming element, keyed to the turn" do
      turn = html(view.ai_chat_message(role: :assistant, id: "m2") { "<p>Done.</p>".html_safe }).at("article#m2")

      expect(turn["class"]).to eq("UnmagicMessage UnmagicMessage--row UnmagicAIChatMessage UnmagicAIChatMessage--assistant")
      expect(turn.at(".UnmagicVisuallyHidden").text).to eq("Assistant said")
      expect(turn.at(".UnmagicMessage__avatar")).to be_nil
      body = turn.at("unmagic-streaming-markdown#m2_content")
      expect(body["class"]).to eq("UnmagicStreamingMarkdown UnmagicMessage__body UnmagicProse")
      expect(body.at("p").text).to eq("Done.")
      expect(body["aria-busy"]).to be_nil
      expect(turn.key?("hidden")).to be(false)
    end

    it "uses a plain body when there's no id to stream into" do
      turn = html(view.ai_chat_message("<p>x</p>".html_safe, role: :assistant)).at(".UnmagicAIChatMessage")
      expect(turn.at("unmagic-streaming-markdown")).to be_nil
      expect(turn.at("div.UnmagicMessage__body.UnmagicProse p")).not_to be_nil
    end

    it "shows the thinking spinner while streaming with nothing yet, busy" do
      body = html(view.ai_chat_message(role: :assistant, id: "m3", streaming: true)).at("#m3_content")

      expect(body["aria-busy"]).to eq("true")
      expect(body.at(".UnmagicAIChatMessage__thinking .UnmagicAIChatSpinner")).not_to be_nil
      expect(body.at(".UnmagicAIChatMessage__thinking").text).to eq("Thinking")
    end

    it "marks a final turn so no late flush lands" do
      body = html(view.ai_chat_message(role: :assistant, id: "m4", streaming: true, final: true) { "Stopped." }).at("#m4_content")
      expect(body.key?("final")).to be(true)
      expect(body["aria-busy"]).to be_nil
    end

    it "hides a settled assistant turn with nothing to say, keeping its id" do
      turn = html(view.ai_chat_message(role: :assistant, id: "m5")).at("#m5")
      expect(turn.key?("hidden")).to be(true)
      expect(html(view.ai_chat_message(role: :user, id: "m6")).at("#m6").key?("hidden")).to be(false)
    end

    it "renders its parts where they belong" do
      turn = html(view.ai_chat_message(role: :assistant, id: "m7") do |message|
        message.reasoning(duration: 12) { "Mulling" }
        message.actions "ACTIONS"
        message.branches { "BRANCHES" }
        "Answer"
      end).at("#m7")

      main = turn.at("> .UnmagicMessage__main")
      expect(main.element_children.map { |child| child["class"] }).to eq([
        "UnmagicMessage__header", "UnmagicAIChatReasoning", "UnmagicStreamingMarkdown UnmagicMessage__body UnmagicProse",
        "UnmagicAIChatMessage__footer"
      ])
      expect(turn.at(".UnmagicMessage__actions")).to be_nil
      expect(turn.at(".UnmagicAIChatMessage__footer").text).to eq("BRANCHESACTIONS")
      expect(turn.at(".UnmagicAIChatReasoning__title").text).to eq("Thought for 12s")

      user = html(view.ai_chat_message(role: :user, id: "m8") do |message|
        message.attachments "FILES"
        "Hi"
      end).at("#m8")
      expect(user.at(".UnmagicMessage__body + .UnmagicMessage__attachments").text).to eq("FILES")
    end

    it "renders the optimistic template for the composer to fill" do
      turn = html(view.ai_chat_message(role: :user, id: "ignored",
        optimistic: { id: "message[client_id]", text: "message[content]" })).at(".UnmagicAIChatMessage")

      expect(turn["id"]).to be_nil
      expect(turn["data-optimistic-id"]).to eq("message[client_id]")
      expect(turn.key?("data-optimistic")).to be(true)
      expect(turn.at(".UnmagicMessage__body")["data-optimistic-text"]).to eq("message[content]")
    end

    it "rejects an unknown role and a half-described optimistic turn" do
      expect { view.ai_chat_message(role: :system) }.to raise_error(ArgumentError, /unknown ai_chat_message role :system/)
      expect { view.ai_chat_message(role: :assistant, optimistic: { id: "a", text: "b" }) }
        .to raise_error(ArgumentError, /only a user turn/)
      expect { view.ai_chat_message(role: :user, optimistic: { id: "a" }) }.to raise_error(ArgumentError, /needs id: and text:/)
    end
  end

  describe "#ai_chat_reasoning" do
    it "renders a shut disclosure of prose" do
      details = html(view.ai_chat_reasoning(class: "extra") { "Considering…" }).at("details.UnmagicAIChatReasoning")

      expect(details["class"]).to eq("UnmagicAIChatReasoning extra")
      expect(details.key?("open")).to be(false)
      expect(details.at("summary .UnmagicAIChatReasoning__title").text).to eq("Thought process")
      expect(details.at("summary .UnmagicAIChatChevron")).not_to be_nil
      expect(details.at(".UnmagicAIChatReasoning__block.UnmagicProse").text).to eq("Considering…")
    end

    it "renders nothing when there's no reasoning" do
      expect(view.ai_chat_reasoning).to be_blank
      expect(view.ai_chat_reasoning { "" }).to be_blank
    end

    it "says it's thinking while streaming, even before any text" do
      summary = html(view.ai_chat_reasoning(streaming: true)).at("summary")
      expect(summary["aria-busy"]).to eq("true")
      expect(summary.text).to eq("Thinking…")
      expect(summary.at(".UnmagicAIChatSpinner")).not_to be_nil
    end

    it "groups several blocks, and takes a title and open" do
      details = html(view.ai_chat_reasoning(title: "Working", open: true) do |reasoning|
        reasoning.block "Two"
        "One"
      end).at("details")

      expect(details.key?("open")).to be(true)
      expect(details.at(".UnmagicAIChatReasoning__title").text).to eq("Working")
      expect(details.css(".UnmagicAIChatReasoning__block").map(&:text)).to eq(%w[One Two])
    end
  end
end
