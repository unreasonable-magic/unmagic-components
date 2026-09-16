# frozen_string_literal: true

RSpec.describe "AI chat requests, permissions and proposals" do
  let(:view) { build_view }

  describe "#ai_chat_request" do
    it "asks with choices while waiting, in real fieldsets" do
      card = html(view.ai_chat_request(state: :waiting, url: "/answers", prompt: "Before I start:", class: "extra") do |request|
        request.question "Which chats?", header: "Scope" do |q|
          q.option "This chat", description: "Only this one"
          q.option "Any chat"
        end
        request.question "Which formats?", multiple: true do |q|
          q.option "PDF"
        end
        request.aside "Or say something else below."
      end).at(".UnmagicAIChatRequest")

      expect(card["class"]).to eq("UnmagicAIChatRequest UnmagicAIChatRequest--waiting extra")
      expect(card["role"]).to be_nil
      expect(card.at(".UnmagicAIChatRequest__head").text).to eq("Wants to know")
      expect(card.at(".UnmagicAIChatRequest__prompt").text).to eq("Before I start:")

      form = card.at("form.UnmagicAIChatRequest__form")
      expect(form["action"]).to eq("/answers")
      expect(form.at("input[name=_method]")["value"]).to eq("patch")

      first, second = form.css("fieldset.UnmagicAIChatRequest__question")
      expect(first.at("legend .UnmagicAIChatRequest__header").text).to eq("Scope")
      expect(first.at("legend .UnmagicAIChatRequest__label").text).to eq("Which chats?")
      radios = first.css("input[type=radio]")
      expect(radios.map { |radio| [ radio["name"], radio["value"], radio["required"] ] })
        .to eq([ [ "answers[0][]", "This chat", "required" ], [ "answers[0][]", "Any chat", "required" ] ])
      expect(radios.first["class"]).to eq("UnmagicRadio")
      expect(first.at(".UnmagicAIChatRequest__choiceDescription").text).to eq("Only this one")

      box = second.at("input[type=checkbox]")
      expect([ box["name"], box["required"], box["class"] ]).to eq([ "answers[1][]", nil, "UnmagicCheck" ])

      expect(form.at(".UnmagicAIChatRequest__actions button[type=submit]").text).to eq("Answer")
      expect(form.at(".UnmagicAIChatRequest__aside").text).to eq("Or say something else below.")
    end

    it "keeps its questions once answered, showing what was picked" do
      card = html(view.ai_chat_request(state: :accepted) do |request|
        request.question("Which chats?", picked: [ "This chat", "Any chat" ]) { |q| q.option "This chat" }
        request.question("Anything else?", picked: nil)
      end).at(".UnmagicAIChatRequest")

      expect(card.at("form, input")).to be_nil
      expect(card.at(".UnmagicAIChatRequest__head").text).to eq("Wanted to knowSubmitted")
      picked = card.css(".UnmagicAIChatRequest__picked")
      expect(picked.map(&:text)).to eq([ "This chat and Any chat", "No answer." ])
      expect(picked.last["class"]).to include("UnmagicAIChatRequest__picked--none")
    end

    it "asks with the caller's own fields, and declines without validating" do
      form = html(view.ai_chat_request(state: :waiting, url: "/e/1", method: :post) do |request|
        request.form { |fields| fields.text_field :name }
        request.decline
      end).at("form")

      expect(form.at("input[name='response[name]']")["class"]).to eq("UnmagicInput")
      decline = form.at("button[name=decline]")
      expect([ decline["value"], decline.key?("formnovalidate"), decline.text ]).to eq([ "1", true, "Decline" ])
    end

    it "lists what was sent back for an answered form" do
      card = html(view.ai_chat_request(state: :declined, prompt: "Your details") { |r| r.answer "Name", "Ana" })
      expect(card.at(".UnmagicAIChatRequest__outcome").text).to eq("Declined")
      expect(card.at("dl .UnmagicAIChatRequest__answer dt").text).to eq("Name")
      expect(card.at("dl .UnmagicAIChatRequest__answer dd").text).to eq("Ana")
    end

    it "is an alert only when streamed in and still waiting" do
      expect(html(view.ai_chat_request(state: :waiting, url: "/a", live: true)).at("div")["role"]).to eq("alert")
      expect(html(view.ai_chat_request(state: :accepted, live: true)).at("div")["role"]).to be_nil
    end

    it "rejects an unknown state, a waiting card with nowhere to post, and both kinds of ask" do
      expect { view.ai_chat_request(state: :pondering) }.to raise_error(ArgumentError, /unknown ai_chat_request state :pondering/)
      expect { view.ai_chat_request(state: :waiting) }.to raise_error(ArgumentError, /needs a url/)
      expect do
        view.ai_chat_request(state: :waiting, url: "/a") do |request|
          request.question "?"
          request.form { "" }
        end
      end.to raise_error(ArgumentError, /not both/)
    end
  end

  describe "#ai_chat_permission" do
    it "puts the ask above the reasoning, with a prominent allow and a wider one" do
      card = html(view.ai_chat_permission(tool: "delete_resource", state: :waiting, url: "/permissions/1",
        live: true, class: "extra") do |ask|
        ask.argument "chat_id", 42
        ask.summary "Remove the drafts"
        ask.reason { "They're duplicates" }
        ask.example "draft-1.png"
        ask.allow confirm: "Delete files? This can't be undone."
        ask.allow "Allow for any chat", params: { widened: true }
        ask.refuse
      end).at(".UnmagicAIChatPermission")

      expect(card["class"]).to eq("UnmagicAIChatPermission UnmagicAIChatPermission--waiting extra")
      expect([ card["role"], card["tabindex"] ]).to eq([ "alert", "-1" ])
      expect(card.at(".UnmagicAIChatPermission__head").text).to eq("Wants permission")
      expect(card.at(".UnmagicAIChatPermission__ask code").text).to eq("delete_resource")
      expect(card.at(".UnmagicAIChatPermission__argument").text).to eq("chat_id: 42")
      expect(card.at(".UnmagicAIChatPermission__summary").text).to eq("Remove the drafts")
      expect(card.at(".UnmagicAIChatPermission__examples li").text).to eq("draft-1.png")

      allow, widen, refuse = card.css(".UnmagicAIChatPermission__actions form")
      expect(allow["data-turbo-confirm"]).to eq("Delete files? This can't be undone.")
      expect(allow.at("button")["class"]).to eq("UnmagicButton UnmagicAIChatPermission__allow")
      expect(widen.at("input[name=widened]")["value"]).to eq("true")
      expect(widen.at("button")["class"]).to include("UnmagicAIChatPermission__widen")
      expect(widen["data-turbo-confirm"]).to be_nil
      expect(refuse.at("input[name=_method]")["value"]).to eq("delete")
      expect(refuse.at("button").text).to eq("Refuse")
    end

    it "says how it went once answered, with no actions" do
      {
        granted: "Allowed.",
        refused: "Refused.",
        lapsed: "Answered in the chat — nothing was granted."
      }.each do |state, sentence|
        card = html(view.ai_chat_permission(tool: "x", state: state, live: true) { |ask| ask.allow }).at(".UnmagicAIChatPermission")
        expect(card.at(".UnmagicAIChatPermission__outcome").text).to eq(sentence)
        expect(card.at("form")).to be_nil
        expect([ card["role"], card["tabindex"] ]).to eq([ nil, nil ])
        expect(card.at(".UnmagicAIChatPermission__head").text).to eq("Wanted permission")
      end

      expect(html(view.ai_chat_permission(tool: "x", state: :granted, outcome: "Allowed for any chat."))
        .at(".UnmagicAIChatPermission__outcome").text).to eq("Allowed for any chat.")
    end

    it "rejects an unknown state and a waiting card with nowhere to post" do
      expect { view.ai_chat_permission(tool: "x", state: :maybe) }.to raise_error(ArgumentError, /unknown ai_chat_permission state :maybe/)
      expect { view.ai_chat_permission(tool: "x", state: :waiting) }.to raise_error(ArgumentError, /needs a url/)
    end
  end

  describe "#ai_chat_proposal" do
    it "offers its actions while pending, named by its claim" do
      aside = html(view.ai_chat_proposal(id: "fact_7", class: "extra") do |offer|
        offer.claim "Prefers to be called Ana"
        offer.meta "About Ana Silva · 80% sure"
        offer.accept "SAVE"
        offer.reject { "DISMISS" }
      end).at("aside#fact_7")

      expect(aside["class"]).to eq("UnmagicAIChatProposal UnmagicAIChatProposal--pending not-prose extra")
      expect(aside["aria-labelledby"]).to eq("fact_7_claim")
      expect(aside.at("#fact_7_claim").text).to eq("Prefers to be called Ana")
      expect(aside.at(".UnmagicAIChatProposal__meta").text).to eq("About Ana Silva · 80% sure")
      expect(aside.at(".UnmagicAIChatProposal__actions").text).to eq("SAVEDISMISS")
    end

    it "settles into a decided state" do
      accepted = html(view.ai_chat_proposal(state: :accepted) do |o|
        o.claim "x"
        o.accept "SAVE"
      end)
      expect(accepted.at(".UnmagicAIChatProposal__actions")).to be_nil
      expect(accepted.at(".UnmagicAIChatProposal__outcome").text).to eq("Saved")

      rejected = html(view.ai_chat_proposal(state: :rejected) { |o| o.outcome "No thanks" })
      expect(rejected.at("aside")["class"]).to include("UnmagicAIChatProposal--rejected")
      expect(rejected.at(".UnmagicAIChatProposal__outcome").text).to eq("No thanks")
    end

    it "derives a claim id when given none, and rejects an unknown state" do
      aside = html(view.ai_chat_proposal { |o| o.claim "x" }).at("aside")
      expect(aside.at("##{aside["aria-labelledby"]}").text).to eq("x")
      expect { view.ai_chat_proposal(state: :later) }.to raise_error(ArgumentError, /unknown ai_chat_proposal state :later/)
    end
  end
end
