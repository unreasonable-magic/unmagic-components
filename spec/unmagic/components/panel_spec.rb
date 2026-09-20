# frozen_string_literal: true

RSpec.describe "panels" do
  let(:view) { build_view }

  describe "#panel" do
    it "puts the tab list in the card's bar and the panels in its body, inside one <unmagic-tabs>" do
      doc = html(view.panel(id: "notes") do |panel|
        panel.tab "README", icon: :book_open
        panel.tab "Agents", icon: :bot, active: true
        panel.panel { "The readme" }
        panel.panel { "The brief" }
      end)

      root = doc.at("unmagic-tabs#notes")
      expect(root["class"]).to eq("UnmagicCard UnmagicPanel UnmagicTabs UnmagicTabs--bar")
      tabs = root.css("> header.UnmagicCard__bar.UnmagicPanel__bar > [role=tablist] > [role=tab]")
      expect(tabs.map { |tab| tab.text.strip }).to eq(%w[README Agents])
      expect(tabs.map { |tab| tab.at("svg.UnmagicTabs__icon")["data-unmagic-icon"] }).to eq(%w[unmagic_components:lucide/book-open unmagic_components:lucide/bot])
      expect(tabs.map { |tab| tab["aria-selected"] }).to eq(%w[false true])

      panels = root.css("> .UnmagicCard__body--flush > [role=tabpanel]")
      expect(panels.map { |panel| [ panel["id"], panel.key?("hidden") ] }).to eq([ [ "notes_panel_0", true ], [ "notes_panel_1", false ] ])
      expect(panels.map { |panel| panel["aria-labelledby"] }).to eq(%w[notes_tab_0 notes_tab_1])
    end

    it "is a plain section with a bar of links and the block as its body when the tabs are pages" do
      doc = html(view.panel(id: "file", flush: true, class: "mt-4") do |panel|
        panel.tab "Source", href: "/files/1?view=source", active: true, icon: :code
        panel.tab "Preview", href: "/files/1?view=preview"
        "The source"
      end)

      root = doc.at("section#file")
      expect(root["class"]).to eq("UnmagicCard UnmagicPanel UnmagicPanel--flush mt-4")
      expect(doc.at("unmagic-tabs")).to be_nil
      links = root.css("> header > nav.UnmagicTabs.UnmagicTabs--bar > .UnmagicTabs__list > a.UnmagicTabs__tab")
      expect(links.map { |link| [ link.text.strip, link["aria-current"] ] }).to eq([ [ "Source", "page" ], [ "Preview", nil ] ])
      expect(root.at("> .UnmagicCard__body").text).to eq("The source")
    end

    it "takes an icon as markup and rejects what tabs rejects" do
      doc = html(view.panel do |panel|
        panel.tab "One", icon: '<svg class="mine"></svg>'.html_safe
        panel.panel { "1" }
      end)
      expect(doc.at("[role=tab] svg.mine")).to be_present
      expect(doc.at("unmagic-tabs")["id"]).to match(/\Aunmagic_panel_\h{8}\z/)

      expect do
        view.panel do |panel|
          panel.tab "One", href: "/"
          panel.panel { "x" }
        end
      end.to raise_error(ArgumentError, /can't mix href: tabs with panels/)
    end
  end
end
