# frozen_string_literal: true

RSpec.describe "Messaging: threads, messages, actions, attachments, reactions, separators and typing" do
  let(:view) { build_view }

  describe "#message_thread" do
    it "renders a plain container with its content, and a live log when asked" do
      plain = html(view.message_thread(id: "t", class: "extra", data: { x: 1 }) { "<p>Hi</p>".html_safe }).at("div#t")
      expect(plain["class"]).to eq("UnmagicMessageThread extra")
      expect([ plain["role"], plain["aria-live"], plain["aria-label"], plain["data-x"] ]).to eq([ nil, nil, nil, "1" ])
      expect(plain.at("p").text).to eq("Hi")

      live = html(view.message_thread(live: true, label: "Chat with Ana") { "" }).at("div")
      expect([ live["role"], live["aria-live"], live["aria-relevant"], live["aria-label"] ])
        .to eq([ "log", "polite", "additions", "Chat with Ana" ])
    end

    it "drops the label without live, and renders with nothing in it" do
      doc = html(view.message_thread(label: "Chat"))
      expect(doc.at("div.UnmagicMessageThread")).not_to be_nil
      expect(doc.at("div")["aria-label"]).to be_nil
    end
  end

  describe "#message" do
    it "renders a bubble from someone else with its header and escaped body" do
      sent = Time.utc(2026, 9, 12, 14, 2)
      article = html(view.message("<b>Hi</b>\nthere", author: "Ana Silva", avatar: true, time: sent, id: "m1", class: "extra")).at("article#m1")

      expect(article["class"]).to eq("UnmagicMessage UnmagicMessage--bubble extra")
      avatar = article.at("> .UnmagicMessage__avatar .UnmagicAvatar--small")
      expect([ avatar["aria-hidden"], avatar.at(".UnmagicAvatar__initials").text ]).to eq([ "true", "AS" ])
      header = article.at("> .UnmagicMessage__main > .UnmagicMessage__header")
      expect(header.at(".UnmagicMessage__author").text).to eq("Ana Silva")
      expect(header.at("unmagic-time.UnmagicMessage__time")["format"]).to eq("time")
      body = article.at(".UnmagicMessage__main > .UnmagicMessage__body")
      expect(body.text).to eq("<b>Hi</b>\nthere")
      expect(body["class"]).not_to include("UnmagicProse")
      expect(article.at(".UnmagicMessage__footer")).to be_nil
    end

    it "marks an own message, says whose it is when there's no author, and trims a block" do
      article = html(view.message(own: true) { "\n   Yes\n " }).at("article")
      expect(article["class"]).to eq("UnmagicMessage UnmagicMessage--bubble UnmagicMessage--own")
      expect(article.at(".UnmagicMessage__header > .UnmagicVisuallyHidden").text).to eq("You")
      expect(article.at(".UnmagicMessage__body").text).to eq("Yes")
      expect(html(view.message("x", own: true, author: "Me")).at(".UnmagicVisuallyHidden")).to be_nil
    end

    it "takes the content as the body when the block only records parts" do
      article = html(view.message("Will do", own: true) { |m| m.status :sent }).at("article")
      expect(article.at(".UnmagicMessage__body").text).to eq("Will do")
      expect(article["data-status"]).to eq("sent")
    end

    it "renders a row and an email as prose, with the variant's avatar size and time format" do
      row = html(view.message("<p>x</p>".html_safe, variant: :row, author: "Ana", avatar: { name: "Ana", src: "/a.png" }, time: Time.now)).at("article")
      expect(row["class"]).to eq("UnmagicMessage UnmagicMessage--row")
      expect(row.at(".UnmagicMessage__avatar .UnmagicAvatar--medium img")["src"]).to eq("/a.png")
      expect(row.at(".UnmagicMessage__body")["class"]).to eq("UnmagicMessage__body UnmagicProse")
      expect(row.at(".UnmagicMessage__time")["format"]).to eq("time")

      email = html(view.message("<p>x</p>".html_safe, variant: :email, time: Time.now)).at("article")
      expect(email.at(".UnmagicMessage__time")["format"]).to eq("medium")
      expect(html(view.message("x", variant: :row, time: Time.now, time_format: :relative)).at(".UnmagicMessage__time")["format"]).to eq("relative")
    end

    it "prints a string time as it is, and no header with nothing for it" do
      expect(html(view.message("x", time: "Yesterday")).at("span.UnmagicMessage__time").text).to eq("Yesterday")
      expect(html(view.message("x")).at(".UnmagicMessage__header")).to be_nil
    end

    it "keeps a continued message's author and avatar column while drawing neither" do
      article = html(view.message("x", author: "Ana", avatar: true, continued: true)).at("article")
      expect(article["class"]).to include("UnmagicMessage--continued")
      expect(article.at(".UnmagicMessage__avatar").text).to eq("")
      expect(article.at(".UnmagicMessage__avatar .UnmagicAvatar")).to be_nil
      expect(article.at(".UnmagicMessage__author").text).to eq("Ana")
      expect(html(view.message("x", continued: true)).at(".UnmagicMessage__avatar")).to be_nil
    end

    it "renders its parts in order, building actions, reactions and attachments from a block with an argument" do
      article = html(view.message(variant: :row, id: "m2", author: "Ana", edited: true) do |m|
        m.meta "to Ben"
        m.quote "Can we?", author: "Ben", href: "/messages/1"
        m.attachments { |files| files.file "notes.md", size: 1_240 }
        m.reactions { |r| r.reaction "👍", count: 2 }
        m.status :read, at: Time.utc(2026, 9, 12, 14, 2)
        m.footer { "3 replies" }
        m.actions(reveal: :always) { |bar| bar.action "Reply", "/reply", icon: :reply }
        "<p>Body</p>".html_safe
      end).at("article#m2")

      expect(article["data-status"]).to eq("read")
      main = article.at("> .UnmagicMessage__main")
      expect(main.element_children.map { |child| child["class"] }).to eq(%w[
        UnmagicMessage__header UnmagicMessage__quote UnmagicMessage__body\ UnmagicProse UnmagicMessage__attachments
        UnmagicMessage__reactions UnmagicMessage__footer
      ])
      expect(main.at(".UnmagicMessage__header .UnmagicMessage__meta").text).to eq("to Ben")

      quote = main.at("blockquote.UnmagicMessage__quote")
      expect(quote["cite"]).to eq("/messages/1")
      expect(quote.at("a.UnmagicMessage__quoteAuthor")["href"]).to eq("/messages/1")
      expect(quote.at(".UnmagicMessage__quoteText").text).to eq("Can we?")

      expect(main.at(".UnmagicMessage__attachments .UnmagicMessageAttachments__name").text).to eq("notes.md")
      expect(main.at(".UnmagicMessage__reactions .UnmagicMessageReactions__count").text).to eq("2")

      footer = main.at(".UnmagicMessage__footer")
      expect(footer.at(".UnmagicMessage__edited").text).to eq("Edited")
      status = footer.at(".UnmagicMessage__status")
      expect(status.at("svg")).not_to be_nil
      expect(status.text).to include("Read")
      expect(status.at("unmagic-time")["format"]).to eq("time")
      expect(footer.at(".UnmagicMessage__extra").text).to eq("3 replies")

      bar = article.at("> .UnmagicMessage__actions > unmagic-toolbar")
      expect([ bar["aria-controls"], bar["data-reveal"] ]).to eq([ "m2", "always" ])
      expect(bar.at("a")["aria-label"]).to eq("Reply")
    end

    it "takes markup for a part from a block without an argument, or as content" do
      article = html(view.message("x", id: "m3") do |m|
        m.actions { "BAR" }
        m.reactions "PILLS"
        m.attachments { "FILES" }
      end).at("article")
      expect(article.at(".UnmagicMessage__actions").text).to eq("BAR")
      expect(article.at(".UnmagicMessage__reactions").text).to eq("PILLS")
      expect(article.at(".UnmagicMessage__attachments").text).to eq("FILES")
    end

    it "folds a collapsible message into a details whose summary is the header" do
      article = html(view.message(variant: :email, author: "Ana", avatar: true, time: "Mon", collapsible: true, open: false) do
        "<p>Thanks both. I've booked the room for Friday and sent the invitations along.</p>".html_safe
      end).at("article")

      details = article.at("> details")
      expect(details.key?("open")).to be(false)
      summary = details.at("> summary.UnmagicMessage__summary")
      expect(summary.at("> span.UnmagicMessage__avatar .UnmagicAvatar")).not_to be_nil
      expect(summary.at("> span.UnmagicMessage__header .UnmagicMessage__author").text).to eq("Ana")
      snippet = summary.at("> span.UnmagicMessage__snippet")
      expect([ snippet["aria-hidden"], snippet.text ]).to eq([ "true", "Thanks both. I've booked the room for Friday and sent the invitations along." ])
      expect(details.at("> .UnmagicMessage__main > .UnmagicMessage__header")).to be_nil
      expect(details.at("> .UnmagicMessage__main > .UnmagicMessage__body p")).not_to be_nil
      expect(html(view.message("x", collapsible: true)).at("details").key?("open")).to be(true)
    end

    it "validates its options" do
      expect { view.message("x", variant: :card) }.to raise_error(ArgumentError, /unknown message variant :card/)
      expect { view.message("x", avatar: true) }.to raise_error(ArgumentError, /needs an author/)
      expect { view.message("x") { |m| m.status :lost } }.to raise_error(ArgumentError, /unknown message status state :lost/)
      expect { view.message("x") { |m| m.actions { |bar| bar.copy "x" } } }.to raise_error(ArgumentError, /needs the message's id/)
    end
  end

  describe "#message_actions" do
    it "renders a labelled toolbar of icon controls for a message" do
      bar = html(view.message_actions(for: "message_2", class: "extra") do |b|
        b.copy "The reply"
        b.action "Edit", "/messages/2/edit", icon: :pencil
        b.action "Delete", "/messages/2", icon: :trash_2, method: :delete, confirm: "Delete it?"
        b.control "<i>X</i>".html_safe
      end).at("unmagic-toolbar")

      expect(bar["class"]).to eq("UnmagicMessageActions extra")
      expect([ bar["role"], bar["aria-label"], bar["aria-controls"], bar["data-reveal"] ])
        .to eq([ "toolbar", "Message actions", "message_2", "hover" ])
      expect(bar.at("unmagic-clipboard")["value"]).to eq("The reply")

      edit = bar.at("a")
      expect([ edit["href"], edit["aria-label"], edit["title"], edit["class"] ])
        .to eq([ "/messages/2/edit", "Edit", "Edit", "UnmagicButton UnmagicButton--icon UnmagicMessageActions__action" ])
      form = bar.at("form.UnmagicMessageActions__form")
      expect(form["data-turbo-confirm"]).to eq("Delete it?")
      expect(form.at("input[name=_method]")["value"]).to eq("delete")
      expect(form.at("button")["aria-label"]).to eq("Delete")
      expect(bar.at("i").text).to eq("X")
    end

    it "takes a label and a reveal, renders nothing without controls, and validates" do
      bar = html(view.message_actions(for: "m", reveal: :always, label: "Reply actions") { |b| b.control "X" }).at("unmagic-toolbar")
      expect([ bar["data-reveal"], bar["aria-label"] ]).to eq([ "always", "Reply actions" ])
      expect(view.message_actions(for: "m")).to be_blank
      expect { view.message_actions(for: "") }.to raise_error(ArgumentError, /needs for:/)
      expect { view.message_actions(for: "m", reveal: :never) }.to raise_error(ArgumentError, /unknown message_actions reveal :never/)
    end

    it "falls back to the AI chat translation of its label" do
      I18n.backend.store_translations(:en, unmagic: { components: { ai_chat: { action_bar: { label: "Turn actions" } } } })
      expect(html(view.message_actions(for: "m") { |b| b.control "X" }).at("unmagic-toolbar")["aria-label"]).to eq("Turn actions")
    ensure
      I18n.backend.reload!
    end
  end

  describe "#message_attachments" do
    it "renders the tiles ai_chat_attachments renders" do
      list = html(view.message_attachments(align: :end) { |files| files.file "brief.pdf", size: 204_800, url: "/files/1" }).at("ul")
      expect(list["class"]).to eq("UnmagicMessageAttachments UnmagicMessageAttachments--end")
      expect(list.at("li.UnmagicMessageAttachments__file a.UnmagicMessageAttachments__link")["href"]).to eq("/files/1")
      expect(view.message_attachments).to be_blank
    end
  end

  describe "#message_reactions" do
    it "renders pills as toggling forms, static spans, and an add button" do
      list = html(view.message_reactions(class: "extra") do |r|
        r.reaction "👍", count: 3, reacted: true, names: [ "Ana", "Ben", "You" ], url: "/react/+1"
        r.reaction "🎉", url: "/react/tada", method: :delete
        r.reaction "👀", count: 2, reacted: true
        r.add popovertarget: "picker_1", class: "more"
      end).at("ul")

      expect([ list["class"], list["aria-label"] ]).to eq([ "UnmagicMessageReactions extra", "Reactions" ])
      pressed, other, static, add = list.css("> li")

      form = pressed.at("form.UnmagicMessageReactions__form")
      expect(form["action"]).to eq("/react/+1")
      button = form.at("button.UnmagicMessageReactions__reaction")
      expect([ button["aria-pressed"], button["title"], button["type"] ]).to eq([ "true", "Ana, Ben, and You", "submit" ])
      expect(button.at(".UnmagicMessageReactions__emoji").text).to eq("👍")
      expect(button.at(".UnmagicMessageReactions__count").text).to eq("3")

      expect(other.at("input[name=_method]")["value"]).to eq("delete")
      expect(other.at("button")["aria-pressed"]).to eq("false")
      expect(other.at(".UnmagicMessageReactions__count").text).to eq("1")

      span = static.at("span.UnmagicMessageReactions__reaction")
      expect(span.key?("data-reacted")).to be(true)
      expect(span.at(".UnmagicVisuallyHidden").text).to eq("You reacted")

      more = add.at("button.UnmagicMessageReactions__add")
      expect([ more["type"], more["aria-label"], more["title"], more["popovertarget"] ]).to eq([ "button", "Add reaction", "Add reaction", "picker_1" ])
      expect(more["class"]).to eq("UnmagicButton UnmagicButton--icon UnmagicMessageReactions__add more")
      expect(more.at("svg")).not_to be_nil
    end

    it "takes markup for the add control, a label, and renders nothing empty" do
      list = html(view.message_reactions(label: "Votes") { |r| r.add { "<i>pick</i>".html_safe } }).at("ul")
      expect(list["aria-label"]).to eq("Votes")
      expect(list.at("li i").text).to eq("pick")
      expect(view.message_reactions).to be_blank
    end
  end

  describe "#message_separator" do
    it "renders a label, a date, or an unread marker" do
      label = html(view.message_separator("Today", class: "extra")).at("div")
      expect(label["class"]).to eq("UnmagicMessageSeparator extra")
      expect([ label["role"], label.at(".UnmagicMessageSeparator__label").text ]).to eq([ nil, "Today" ])

      dated = html(view.message_separator(time: Date.new(2026, 9, 12))).at("div")
      expect(dated.at(".UnmagicMessageSeparator__label unmagic-time")["format"]).to eq("date")
      expect(html(view.message_separator("Yesterday", time: Date.new(2026, 9, 12))).at("unmagic-time")).to be_nil

      unread = html(view.message_separator(unread: true)).at("div")
      expect([ unread.key?("data-unread"), unread.at(".UnmagicMessageSeparator__label").text ]).to eq([ true, "New messages" ])
      expect(html(view.message_separator("3 new", unread: true)).at(".UnmagicMessageSeparator__label").text).to eq("3 new")

      bare = html(view.message_separator).at("div")
      expect(bare.at("span")).to be_nil
    end
  end

  describe "#message_typing" do
    it "reads as a sentence, with the dots and the visible name hidden from assistive tech" do
      named = html(view.message_typing("Ana Silva", avatar: true, class: "extra")).at("div")
      expect(named["class"]).to eq("UnmagicMessageTyping extra")
      expect(named["role"]).to be_nil
      expect(named.at(".UnmagicMessageTyping__avatar .UnmagicAvatar--small .UnmagicAvatar__initials").text).to eq("AS")
      expect(named.at(".UnmagicMessageTyping__author")["aria-hidden"]).to eq("true")
      bubble = named.at(".UnmagicMessageTyping__bubble")
      expect([ bubble["aria-hidden"], bubble.css("i").size ]).to eq([ "true", 3 ])
      expect(named.at(".UnmagicVisuallyHidden").text).to eq("Ana Silva is typing")

      anonymous = html(view.message_typing(role: "status")).at("div")
      expect(anonymous["role"]).to eq("status")
      expect(anonymous.at(".UnmagicMessageTyping__author")).to be_nil
      expect(anonymous.at(".UnmagicVisuallyHidden").text).to eq("Typing")
    end
  end
end
