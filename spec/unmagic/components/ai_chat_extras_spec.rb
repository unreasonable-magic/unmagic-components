# frozen_string_literal: true

RSpec.describe "AI chat citations, welcomes, attachments, menus, action bars and branch pickers" do
  let(:view) { build_view }

  describe "#ai_chat_citation" do
    it "quotes a record as escaped text, attributed and dated" do
      sent = Time.utc(2026, 3, 2, 16, 12)
      figure = html(view.ai_chat_citation(class: "extra") do |cite|
        cite.avatar
        cite.who "Ana Silva"
        cite.when sent, url: "/messages/1"
        cite.quote "<b>Can we</b>\nmove it?"
      end).at("figure")

      expect(figure["class"]).to eq("UnmagicAIChatCitation not-prose extra")
      avatar = figure.at(".UnmagicAIChatCitation__avatar .UnmagicAvatar--small")
      expect([ avatar["aria-hidden"], avatar.at(".UnmagicAvatar__initials").text ]).to eq([ "true", "AS" ])
      expect(figure.at("figcaption .UnmagicAIChatCitation__who").text).to eq("Ana Silva")
      link = figure.at("figcaption a.UnmagicAIChatCitation__when")
      expect(link["href"]).to eq("/messages/1")
      expect(link.at("unmagic-time")["datetime"]).to eq(sent.iso8601)

      quote = figure.at("blockquote.UnmagicAIChatCitation__quote")
      expect(quote.text).to eq("<b>Can we</b>\nmove it?")
      expect(quote.at("b")).to be_nil
      expect(quote["cite"]).to eq("/messages/1")
    end

    it "takes the caller's avatar, and a compact line without one" do
      custom = html(view.ai_chat_citation do |c|
        c.avatar "PIC"
        c.who "Ana"
      end)
      expect(custom.at(".UnmagicAIChatCitation__avatar").text).to eq("PIC")

      compact = html(view.ai_chat_citation(compact: true) do |c|
        c.avatar
        c.who "Handbook"
        c.quote "Four weeks"
      end)
      expect(compact.at("figure")["class"]).to include("UnmagicAIChatCitation--compact")
      expect(compact.at(".UnmagicAIChatCitation__avatar")).to be_nil
      expect(compact.at("blockquote")["cite"]).to be_nil
      expect(compact.at(".UnmagicAIChatCitation__when")).to be_nil
    end

    it "renders nothing given nothing" do
      expect(view.ai_chat_citation).to be_blank
    end
  end

  describe "#ai_chat_welcome" do
    it "renders a heading and suggestions as buttons aimed at the composer" do
      welcome = html(view.ai_chat_welcome(heading: "What can I help with?", heading_tag: :h1, composer: "new_chat",
        field: "chat[prompt]", class: "extra") do |w|
        w.body "It can search your jobs."
        w.suggestion "Who hasn't replied?", icon: :lightbulb
        w.suggestion "Invite…", fill: true, value: "Invite someone to "
      end).at(".UnmagicAIChatWelcome")

      expect(welcome["class"]).to eq("UnmagicAIChatWelcome extra")
      expect(welcome.at("h1.UnmagicAIChatWelcome__heading").text).to eq("What can I help with?")
      expect(welcome.at(".UnmagicAIChatWelcome__body").text).to eq("It can search your jobs.")

      send, fill = welcome.css("ul.UnmagicAIChatWelcome__suggestions > li > button")
      expect([ send["type"], send["data-ai-chat-suggestion"], send["data-ai-chat-suggestion-form"], send["data-ai-chat-suggestion-field"] ])
        .to eq([ "button", "Who hasn't replied?", "new_chat", "chat[prompt]" ])
      expect(send.key?("data-ai-chat-suggestion-fill")).to be(false)
      expect(send.at("svg")).not_to be_nil
      expect([ fill.text, fill["data-ai-chat-suggestion"], fill.key?("data-ai-chat-suggestion-fill") ])
        .to eq([ "Invite…", "Invite someone to ", true ])
    end

    it "has no list without suggestions" do
      expect(html(view.ai_chat_welcome(heading: "Hi")).at("ul")).to be_nil
    end
  end

  describe "#ai_chat_attachments" do
    it "lists files, with a thumbnail or a glyph, linked when they have a url" do
      list = html(view.ai_chat_attachments(align: :end, class: "extra") do |files|
        files.file "brief.pdf", size: 204_800, url: "/files/1"
        files.file "shot.png", thumbnail: "/thumbs/2.png"
      end).at("ul")

      expect(list["class"]).to eq("UnmagicMessageAttachments UnmagicMessageAttachments--end extra")
      pdf, png = list.css("li.UnmagicMessageAttachments__file")
      expect(pdf.at("a")["href"]).to eq("/files/1")
      expect(pdf.at(".UnmagicMessageAttachments__glyph")).not_to be_nil
      expect(pdf.at(".UnmagicMessageAttachments__size").text).to eq("200 KB")
      expect(png.at("img.UnmagicMessageAttachments__thumb")["alt"]).to eq("")
      expect(png.at("a")).to be_nil
    end

    it "renders nothing without files, and rejects an unknown alignment" do
      expect(view.ai_chat_attachments).to be_blank
      expect { view.ai_chat_attachments(align: :middle) }.to raise_error(ArgumentError, /unknown message_attachments align :middle/)
    end
  end

  describe "#ai_chat_dropzone" do
    it "wraps content with a hidden overlay, a live region and a chip template" do
      zone = html(view.ai_chat_dropzone(input: "#files", url: "/uploads", field: "message[paths][]",
        chips: "#chips", label: "Drop to add") { "PAGE" }).at("unmagic-dropzone.UnmagicAIChatDropzone")

      expect([ zone["input"], zone["url"], zone["field"], zone["chips"] ])
        .to eq([ "#files", "/uploads", "message[paths][]", "#chips" ])
      expect(zone["data-attached"]).to eq("{name} attached")
      overlay = zone.at(".UnmagicAIChatDropzone__overlay")
      expect([ overlay["aria-hidden"], overlay.text ]).to eq([ "true", "Drop to add" ])
      expect(zone.text).to include("PAGE")
      expect(zone.at("[data-dropzone-status]")["aria-live"]).to eq("polite")
      expect(zone.at("template[data-dropzone-chip]")).not_to be_nil
    end

    it "needs an input, and a field when it uploads" do
      expect { view.ai_chat_dropzone(input: nil) }.to raise_error(ArgumentError, /needs an input/)
      expect { view.ai_chat_dropzone(input: "#f", url: "/u") }.to raise_error(ArgumentError, /needs a field/)
    end
  end

  describe "#ai_chat_slash_menu" do
    it "renders every command as an option, the first selected" do
      menu = html(view.ai_chat_slash_menu(for: "message_content", id: "skills", above: true) do |m|
        m.item "invite", description: "Invite a candidate", arguments: %w[email]
        m.item "summarise"
      end).at("unmagic-slash-menu")

      expect(menu["class"]).to eq("UnmagicAIChatSlashMenu UnmagicAIChatSlashMenu--above")
      expect([ menu["for"], menu["trigger"], menu.key?("hidden") ]).to eq([ "message_content", "/", true ])
      listbox = menu.at("ul#skills_listbox")
      expect([ listbox["role"], listbox["aria-label"] ]).to eq([ "listbox", "Commands" ])

      first, second = listbox.css("li[role=option]")
      expect([ first["id"], first["data-name"], first["aria-selected"] ]).to eq([ "skills_0", "invite", "true" ])
      expect(first.at(".UnmagicAIChatSlashMenu__name").text).to eq("/invite [email]")
      expect(first.at(".UnmagicAIChatSlashMenu__description").text).to eq("Invite a candidate")
      expect(second["aria-selected"]).to eq("false")
      expect(second.at(".UnmagicAIChatSlashMenu__description")).to be_nil
    end

    it "renders nothing without commands, and takes one trigger character" do
      expect(view.ai_chat_slash_menu).to be_blank
      expect { view.ai_chat_slash_menu(trigger: "//") }.to raise_error(ArgumentError, /one character/)
    end
  end

  describe "#ai_chat_action_bar" do
    it "is message_actions under its old name" do
      bar = html(view.ai_chat_action_bar(for: "message_2", reveal: :always, class: "extra") { |b| b.copy "The reply" }).at("unmagic-toolbar")

      expect(bar["class"]).to eq("UnmagicMessageActions extra")
      expect([ bar["role"], bar["aria-label"], bar["aria-controls"], bar["data-reveal"] ])
        .to eq([ "toolbar", "Message actions", "message_2", "always" ])
      expect(bar.at("unmagic-clipboard")["value"]).to eq("The reply")
    end
  end

  describe "#ai_chat_branch_picker" do
    it "reads its position as a sentence, with a disabled end as a span" do
      picker = html(view.ai_chat_branch_picker(index: 1, count: 3, next: "/messages/2?branch=2", class: "extra")).at("div")

      expect(picker["class"]).to eq("UnmagicAIChatBranchPicker extra")
      expect([ picker["role"], picker["aria-label"] ]).to eq([ "group", "Version 1 of 3" ])
      expect(picker.at(".UnmagicAIChatBranchPicker__count").then { |count| [ count.text, count["aria-hidden"] ] }).to eq([ "1/3", "true" ])

      previous = picker.at("span.UnmagicAIChatBranchPicker__step")
      expect([ previous["aria-disabled"], previous["title"] ]).to eq([ "true", "Previous version" ])
      following = picker.at("a.UnmagicAIChatBranchPicker__step")
      expect([ following["href"], following["aria-label"], following["title"] ])
        .to eq([ "/messages/2?branch=2", "Next version", "Next version" ])
    end

    it "posts when the step isn't a GET" do
      picker = html(view.ai_chat_branch_picker(index: 2, count: 2, previous: "/b/1", method: :patch))
      expect(picker.at("form input[name=_method]")["value"]).to eq("patch")
    end

    it "renders nothing for one version, and rejects an impossible position" do
      expect(view.ai_chat_branch_picker(index: 1, count: 1)).to be_blank
      expect { view.ai_chat_branch_picker(index: 4, count: 3) }.to raise_error(ArgumentError, /outside 1..3/)
      expect { view.ai_chat_branch_picker(index: 1, count: 0) }.to raise_error(ArgumentError, /at least 1/)
    end
  end
end
