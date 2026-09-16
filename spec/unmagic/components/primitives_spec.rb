# frozen_string_literal: true

RSpec.describe "static primitives" do
  let(:view) { build_view }

  describe "#badge" do
    it "renders a pill with its tone" do
      doc = html(view.badge("Draft") + view.badge("Overdue", tone: :bad))

      expect(doc.css("span").map { |span| [ span.text, span["class"] ] }).to eq(
        [ [ "Draft", "UnmagicBadge" ], [ "Overdue", "UnmagicBadge UnmagicBadge--bad" ] ]
      )
    end

    it "takes a block, extra classes and attributes" do
      badge = html(view.badge(tone: :good, class: "ml-2", title: "Live") { "Live" }).at("span")

      expect(badge.text).to eq("Live")
      expect(badge["class"]).to eq("UnmagicBadge UnmagicBadge--good ml-2")
      expect(badge["title"]).to eq("Live")
    end

    it "rejects an unknown tone" do
      expect { view.badge("x", tone: :loud) }.to raise_error(ArgumentError, /unknown badge tone :loud/)
    end
  end

  describe "#card" do
    it "renders a titled section with actions, body and footer" do
      doc = html(view.card(title: "Members", id: "members") do |card|
        card.actions { view.link_to("Invite", "/invitations/new") }
        card.footer { "3 of 5 seats used" }
        "Body"
      end)

      card = doc.at("section.UnmagicCard#members")
      expect(card.at("> header .UnmagicCard__title").text).to eq("Members")
      expect(card.at("> header .UnmagicCard__actions a").text).to eq("Invite")
      expect(card.at("> .UnmagicCard__body").text).to eq("Body")
      expect(card.at("> .UnmagicCard__footer").text).to eq("3 of 5 seats used")
    end

    it "omits the header and footer when nothing fills them" do
      card = html(view.card { "Body" }).at("section")

      expect(card.at("header")).to be_nil
      expect(card.at(".UnmagicCard__footer")).to be_nil
    end

    it "becomes one link with href:" do
      card = html(view.card(href: "/labels/1") { "Bug" }).at("a")

      expect(card["href"]).to eq("/labels/1")
      expect(card["class"]).to eq("UnmagicCard UnmagicCard--link")
    end

    it "drops the body padding with flush: true" do
      body = html(view.card(flush: true) { "Rows" }).at(".UnmagicCard__body")

      expect(body["class"]).to eq("UnmagicCard__body UnmagicCard__body--flush")
    end
  end

  describe "#page_header" do
    it "renders the back link, title, badges, description and actions" do
      doc = html(view.page_header(title: "Bug", description: "Applied to 12 issues.",
        back: { text: "Labels", path: "/labels" }) do |header|
        header.badge "Archived", tone: :warn
        view.link_to("Edit", "/labels/1/edit")
      end)

      header = doc.at("header.UnmagicPageHeader")
      back = header.at("a.UnmagicPageHeader__back")
      expect(back["href"]).to eq("/labels")
      expect(back.text).to eq("Labels")
      expect(header.at("h1.UnmagicPageHeader__title").text).to eq("Bug")
      expect(header.at(".UnmagicPageHeader__heading .UnmagicBadge--warn").text).to eq("Archived")
      expect(header.at(".UnmagicPageHeader__description").text).to eq("Applied to 12 issues.")
      expect(header.at(".UnmagicPageHeader__actions a").text).to eq("Edit")
    end

    it "puts already-rendered markup beside the title with trailing, unwrapped" do
      doc = html(view.page_header(title: "Errand") do |header|
        header.trailing view.badge("running", tone: :accent)
        header.trailing { view.tag.span("queued", class: "custom") }
        nil
      end)

      heading = doc.at(".UnmagicPageHeader__heading")
      # One badge, not a badge inside a badge — which is what routing an already
      # rendered one through #badge would have produced.
      expect(heading.css(".UnmagicBadge").length).to eq(1)
      expect(heading.at(".UnmagicBadge")["class"]).to eq("UnmagicBadge UnmagicBadge--accent")
      expect(heading.at(".UnmagicBadge .UnmagicBadge")).to be_nil
      expect(heading.at("span.custom").text).to eq("queued")
    end

    it "keeps trailing and badge in the order they were called" do
      doc = html(view.page_header(title: "Errand") do |header|
        header.badge "Archived", tone: :warn
        header.trailing view.tag.span("via Fastmail", class: "source")
        nil
      end)

      marks = doc.at(".UnmagicPageHeader__heading").element_children.drop(1)
      expect(marks.map { |node| node["class"] }).to eq([ "UnmagicBadge UnmagicBadge--warn", "source" ])
    end

    it "takes the title, description and leading from blocks" do
      doc = html(view.page_header do |header|
        header.leading { view.tag.img(src: "/avatar.png", alt: "") }
        header.title { view.tag.code("deploy_key") }
        header.description { view.tag.strong("Read-only") }
        nil
      end)

      expect(doc.at(".UnmagicPageHeader__heading > img")).not_to be_nil
      expect(doc.at("h1 code").text).to eq("deploy_key")
      expect(doc.at(".UnmagicPageHeader__description strong").text).to eq("Read-only")
    end

    it "leaves out the back link, description and actions when not given" do
      doc = html(view.page_header(title: "Labels"))

      expect(doc.at(".UnmagicPageHeader__back")).to be_nil
      expect(doc.at(".UnmagicPageHeader__description")).to be_nil
      expect(doc.at(".UnmagicPageHeader__actions")).to be_nil
    end
  end

  describe "#callout" do
    it "renders a toned callout with its icon, title, badge and body" do
      doc = html(view.callout("DNS isn't verified", tone: :warn, badge: "Pending") { "Add the TXT record." })

      callout = doc.at(".UnmagicCallout")
      expect(callout["class"]).to eq("UnmagicCallout UnmagicCallout--warn")
      expect(callout.at("> svg.UnmagicCallout__icon")).not_to be_nil
      expect(callout.at(".UnmagicCallout__title").text).to eq("DNS isn't verified")
      expect(callout.at(".UnmagicCallout__heading .UnmagicBadge")["class"]).to eq("UnmagicBadge UnmagicBadge--warn")
      expect(callout.at(".UnmagicCallout__body").text).to eq("Add the TXT record.")
    end

    it "has no icon when neutral or when icon: false, and no heading without a title or badge" do
      neutral = html(view.callout { "Note" })
      iconless = html(view.callout(tone: :bad, icon: false) { "Note" })

      expect(neutral.at("svg")).to be_nil
      expect(neutral.at(".UnmagicCallout__heading")).to be_nil
      expect(iconless.at("svg")).to be_nil
    end

    it "rejects an unknown tone" do
      expect { view.callout(tone: :loud) { "x" } }.to raise_error(ArgumentError, /unknown callout tone :loud/)
    end
  end

  describe "#empty_state" do
    it "renders the blank slate from a string or a block" do
      expect(html(view.empty_state("No invitations yet.")).at("div.UnmagicEmptyState").text).to eq("No invitations yet.")
      expect(html(view.empty_state { view.tag.strong("Nothing") }).at(".UnmagicEmptyState strong").text).to eq("Nothing")
    end

    it "renders through the configured empty_state seam" do
      Unmagic::Components.configure do |config|
        config.empty_state = ->(view, content, **options) { view.tag.p(content, class: options[:class]) }
      end

      expect(html(view.empty_state("Empty", class: "blank")).at("p.blank").text).to eq("Empty")
    end
  end
end
