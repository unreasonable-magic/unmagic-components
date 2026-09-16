# frozen_string_literal: true

RSpec.describe "the AI chat composer" do
  let(:view) { build_view }

  def composer(id: "composer", **options, &block)
    html(view.form_with(scope: :message, url: "/messages", id: id) do |form|
      view.ai_chat_composer(form: form, field: :content, **options, &block)
    end)
  end

  it "renders a bare autogrowing field and a Send button naming the form" do
    doc = composer(placeholder: "Ask for something…", class: "extra")
    root = doc.at("form#composer > .UnmagicAIChatComposer")

    expect(root["class"]).to eq("UnmagicAIChatComposer extra")
    field = root.at(".UnmagicAIChatComposer__box unmagic-autogrow > textarea")
    expect(field["name"]).to eq("message[content]")
    expect(field["id"]).to eq("message_content")
    expect(field["class"]).to eq("UnmagicAIChatComposer__field")
    expect([ field["required"], field["rows"], field["placeholder"], field["aria-label"] ])
      .to eq([ "required", "2", "Ask for something…", "Ask for something…" ])
    expect(field.key?("data-ai-chat-composer-field")).to be(true)

    action = root.at("#composer_action")
    expect(action["aria-live"]).to eq("polite")
    send = action.at("button")
    expect([ send["type"], send["form"], send.text ]).to eq([ "submit", "composer", "Send" ])
    expect(send["class"]).to eq("UnmagicButton UnmagicButton--primary")
    expect(root.at("[data-ai-chat-chips]")).not_to be_nil
  end

  it "flips only the button as the turn's state changes, never the field" do
    {
      running: [ "stop_turn", "Stop", false ],
      stopping: [ nil, "Stopping…", true ],
      waiting: [ "stop_turn", "Stop", false ]
    }.each do |state, (form, label, disabled)|
      doc = composer(state: state)
      button = doc.at("#composer_action button")

      expect([ button["form"], button.text, button.key?("disabled") ]).to eq([ form, label, disabled ])
      expect(doc.at("textarea").key?("disabled")).to be(false)
    end

    expect(composer(state: :waiting).at(".UnmagicAIChatComposer__hint").text).to eq("Waiting for your input…")
    expect(composer(state: :stopping).at("#composer_action .UnmagicAIChatSpinner")).not_to be_nil
  end

  it "takes a label for Send and a name for the stop form" do
    expect(composer(label: "Start chat").at("#composer_action button").text).to eq("Start chat")
    expect(composer(state: :running, stop_form: "halt").at("#composer_action button")["form"]).to eq("halt")
  end

  it "draws the question optimistically under a minted id" do
    doc = composer { |c| c.optimistic id: "message[client_id]", container: "#entries" }

    optimistic = doc.at("unmagic-optimistic.UnmagicOptimistic")
    expect(optimistic["container"]).to eq("#entries")
    expect(optimistic.at("unmagic-uuid-input")["name"]).to eq("message[client_id]")

    turn = optimistic.at("> template").children.at(".UnmagicAIChatMessage--user") ||
      Nokogiri::HTML5.fragment(optimistic.at("> template").inner_html).at(".UnmagicAIChatMessage--user")
    expect(turn["data-optimistic-id"]).to eq("message[client_id]")
    expect(turn.at(".UnmagicAIChatMessage__bubble")["data-optimistic-text"]).to eq("message[content]")
  end

  it "renders neither the uuid nor the template without optimistic" do
    doc = composer
    expect(doc.at("unmagic-uuid-input")).to be_nil
    expect(doc.at("template")).to be_nil
  end

  it "puts its parts where they belong" do
    root = composer do |c|
      c.menu "MENU"
      c.attach "ATTACH"
      c.actions "ACTIONS"
    end.at(".UnmagicAIChatComposer")

    expect(root.children.first.text).to eq("MENU")
    box = root.at(".UnmagicAIChatComposer__box")
    expect(box.element_children.map { |child| child["class"] })
      .to eq(%w[UnmagicAutogrow UnmagicAIChatComposer__attach UnmagicAIChatComposer__actions UnmagicAIChatComposer__action])
  end

  it "needs a form with an id, and a known state" do
    expect { composer(id: nil) }.to raise_error(ArgumentError, /needs its form to have an id/)
    expect { composer(state: :napping) }.to raise_error(ArgumentError, /unknown ai_chat_composer state :napping/)
  end

  it "renders the action region on its own, for a broadcast" do
    action = html(view.ai_chat_composer_action(form: "composer", state: :running)).at("div#composer_action")
    expect(action.at("button")["form"]).to eq("stop_turn")
  end

  it "renders the empty stop form Stop reaches by id" do
    form = html(view.ai_chat_stop_form("/chats/1/stop")).at("form#stop_turn")
    expect([ form["action"], form["method"], form["class"] ]).to eq([ "/chats/1/stop", "post", "UnmagicAIChatStopForm" ])
    expect(form.css("textarea, button")).to be_empty
  end
end
