# frozen_string_literal: true

RSpec.describe "kbd, breadcrumbs, pagination and empty states" do
  let(:view) { build_view }

  describe "#kbd" do
    it "draws key caps with spoken names for glyphs" do
      kbd = html(view.kbd(:cmd, "K", class: "ml-1")).at("kbd.UnmagicKbd")

      expect(kbd["class"]).to eq("UnmagicKbd ml-1")
      caps = kbd.css("> kbd.UnmagicKbd__key")
      expect(caps.map { |cap| cap.at("[aria-hidden]")&.text || cap.text }).to eq([ "⌘", "K" ])
      expect([ caps[0]["title"], caps[0].at(".UnmagicVisuallyHidden").text ]).to eq(%w[Command Command])
    end

    it "renders both platform modifiers for :mod, guessed from the request, and parses hotkey:" do
      kbd = html(view.kbd(hotkey: "mod+shift+p")).at("kbd")

      expect(kbd["data-platform"]).to eq("other")
      expect(kbd.css("> kbd").map { |cap| cap["class"] }).to eq([
        "UnmagicKbd__key UnmagicKbd__mod UnmagicKbd__mod--apple", "UnmagicKbd__key UnmagicKbd__mod UnmagicKbd__mod--other",
        "UnmagicKbd__key", "UnmagicKbd__key"
      ])
      expect(kbd.css("> kbd").last.text).to eq("p")
    end

    it "joins a sequence with 'then', and rejects bad input" do
      kbd = html(view.kbd("G", "I", sequence: true)).at("kbd")
      expect(kbd["class"]).to eq("UnmagicKbd UnmagicKbd--sequence")
      expect(kbd.at(".UnmagicKbd__joiner").text).to eq("then")

      expect { view.kbd }.to raise_error(ArgumentError, /at least one key/)
      expect { view.kbd(:hyper) }.to raise_error(ArgumentError, /unknown kbd key :hyper/)
      expect { view.kbd("K", hotkey: "mod+k") }.to raise_error(ArgumentError, /not both/)
    end
  end

  describe "#breadcrumbs" do
    it "renders a labelled trail with separators and the current page last" do
      doc = html(view.breadcrumbs(class: "mt-1") do |crumbs|
        crumbs.link "Settings", "/settings"
        crumbs.link "/settings/integrations" do "Integrations" end
        crumbs.current "GitHub"
      end)

      nav = doc.at("nav.UnmagicBreadcrumbs")
      expect([ nav["aria-label"], nav["class"] ]).to eq([ "Breadcrumb", "UnmagicBreadcrumbs mt-1" ])
      items = nav.css("ol.UnmagicBreadcrumbs__list > li.UnmagicBreadcrumbs__item")
      expect(items.map { |item| item.at("svg.UnmagicBreadcrumbs__separator").present? }).to eq([ false, true, true ])
      expect(items.map { |item| (item.at("a") || item.at("span")).text }).to eq(%w[Settings Integrations GitHub])
      expect(items[0].at("a")["title"]).to eq("Settings")
      expect(items.last.at("span")["aria-current"]).to eq("page")
    end

    it "renders nothing when empty, and rejects a second current or a link after it" do
      expect(view.breadcrumbs { |_crumbs| }).to be_nil
      expect { view.breadcrumbs { |c| c.current "A"; c.current "B" } }.to raise_error(ArgumentError, /one current/)
      expect { view.breadcrumbs { |c| c.current "A"; c.link "B", "/" } }.to raise_error(ArgumentError, /after current/)
    end

    it "sits in a page header where the back link goes" do
      header = html(view.page_header(title: "GitHub", mono: true) { |h| h.breadcrumbs { |c| c.link "Settings", "/settings"; c.current "GitHub" } })

      expect(header.at("header > nav.UnmagicBreadcrumbs.UnmagicPageHeader__breadcrumbs")).to be_present
      expect(header.at(".UnmagicPageHeader__title")["class"]).to include("UnmagicPageHeader__title--mono")
      expect do
        view.page_header(title: "x", back: { text: "Back", path: "/" }) { |h| h.breadcrumbs { |c| c.current "x" } }
      end.to raise_error(ArgumentError, /back: or breadcrumbs/)
    end
  end

  describe "#pagination" do
    let(:pager_class) do
      Struct.new(:previous, :next, :page, :last) do
        def page_url(page) = "?page=#{page}"
      end
    end

    it "renders arrows and a window of numbered pages with gaps" do
      nav = html(view.pagination(pager_class.new(5, 7, 6, 12), window: 1, turbo_frame: "results")).at("nav.UnmagicPagination")

      expect(nav["aria-label"]).to eq("Pagination")
      arrows = nav.css("> a.UnmagicPagination__link")
      expect(arrows.map { |a| [ a.text, a["href"], a["rel"], a["data-turbo-frame"] ] }).to eq([ [ "Previous", "?page=previous", "prev", "results" ], [ "Next", "?page=next", "next", "results" ] ])
      pages = nav.css(".UnmagicPagination__page")
      expect(pages.map { |p| p.at(".UnmagicPagination__number").text }).to eq(%w[1 5 6 7 12])
      expect(pages.map { |p| p.at(".UnmagicPagination__gap").present? }).to eq([ false, true, false, false, true ])
      expect(nav.at("[aria-current=page]").text).to eq("6")
      expect(nav.at("a[aria-label='Page 12']")["href"]).to eq("?page=12")
      expect(nav.at(".UnmagicPagination__count").text).to eq("6 of 12")
    end

    it "disables an arrow at either end, skips the numbers for a pager without them, and renders nothing for one page" do
      nav = html(view.pagination(pager_class.new(nil, 2, 1, 3))).at("nav")
      expect(nav.at("span.UnmagicPagination__link")["aria-disabled"]).to eq("true")

      plain = Struct.new(:previous, :next) { def page_url(d) = "?#{d}" }
      expect(html(view.pagination(plain.new(1, 3))).at(".UnmagicPagination__pages")).to be_nil
      expect(view.pagination(plain.new(nil, nil))).to be_nil
      expect(view.pagination(Object.new)).to be_nil
    end
  end

  describe "#empty_state" do
    it "renders an icon, title, text and actions" do
      doc = html(view.empty_state("Import a folder or drop files here.", title: "No files yet", icon: :folder, class: "mt-2") { view.tag.button("Import") })
      root = doc.at(".UnmagicEmptyState")

      expect(root["class"]).to eq("UnmagicEmptyState mt-2")
      expect(root.at("svg.UnmagicEmptyState__icon")).to be_present
      expect(root.at("h3.UnmagicEmptyState__title").text).to eq("No files yet")
      expect(root.at(".UnmagicEmptyState__text").text).to eq("Import a folder or drop files here.")
      expect(root.at(".UnmagicEmptyState__actions button").text).to eq("Import")
    end

    it "is still just the text when that's all it's given" do
      root = html(view.empty_state("Nothing here")).at(".UnmagicEmptyState")
      expect(root.children.map(&:name)).to eq([ "div" ])
      expect(root.text).to eq("Nothing here")
    end
  end
end
