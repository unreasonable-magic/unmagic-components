# frozen_string_literal: true

RSpec.describe "menus, tabs and copy buttons" do
  let(:view) { build_view }

  describe "#menu" do
    it "renders a details dropdown behind an icon trigger" do
      doc = html(view.menu { |menu| menu.link "Edit", "/jobs/1/edit" })

      summary = doc.at("unmagic-menu.UnmagicMenu > details.UnmagicMenu__details > summary")
      expect(summary["aria-label"]).to eq("More actions")
      expect(summary["aria-haspopup"]).to eq("menu")
      expect(summary["class"]).to eq("UnmagicButton UnmagicButton--icon UnmagicMenu__trigger")
      expect(summary.at("svg")).not_to be_nil

      panel = doc.at("details > .UnmagicMenu__panel")
      expect(panel["role"]).to eq("menu")
      expect(panel["class"]).to include("UnmagicMenu__panel--end")
    end

    it "labels a text trigger and aligns the panel to its start" do
      doc = html(view.menu("Options", align: :start) { |menu| menu.divider })

      expect(doc.at("summary").text).to eq("Options")
      expect(doc.at("summary")["aria-label"]).to be_nil
      expect(doc.at(".UnmagicMenu__panel")["class"]).to include("UnmagicMenu__panel--start")
      expect(doc.at("hr.UnmagicMenu__divider")["role"]).to eq("separator")
    end

    it "renders link items, block form included" do
      doc = html(view.menu do |menu|
        menu.link "Edit", "/jobs/1/edit", class: "extra"
        menu.link("/jobs/1") { "View" }
      end)

      edit, show = doc.css("a[role=menuitem]")
      expect([ edit.text, edit["href"], edit["class"] ]).to eq([ "Edit", "/jobs/1/edit", "UnmagicMenu__item extra" ])
      expect([ show.text, show["href"] ]).to eq([ "View", "/jobs/1" ])
    end

    it "renders button items as forms, keeping their confirm and tone" do
      doc = html(view.menu do |menu|
        menu.button "Delete", "/jobs/1", method: :delete, tone: :danger, form: { data: { turbo_confirm: "Sure?" } }
      end)

      form = doc.at("form.UnmagicMenu__form")
      expect(form["action"]).to eq("/jobs/1")
      expect(form["data-turbo-confirm"]).to eq("Sure?")
      expect(form.at("input[name=_method]")["value"]).to eq("delete")

      button = form.at("button[role=menuitem]")
      expect(button.text).to eq("Delete")
      expect(button["class"]).to eq("UnmagicMenu__item UnmagicMenu__item--danger")
    end

    it "rejects an unknown align or tone" do
      expect { view.menu(align: :middle) { nil } }.to raise_error(ArgumentError, /unknown menu align :middle/)
      expect { view.menu { |menu| menu.link "x", "/", tone: :loud } }.to raise_error(ArgumentError, /unknown menu item tone :loud/)
    end
  end

  describe "#tabs" do
    let(:markup) do
      view.tabs(id: "response") do |tabs|
        tabs.tab "Body"
        tabs.tab "Headers", active: true
        tabs.tab "Preview", disabled: "HTML only"
        tabs.panel { "The body" }
        tabs.panel { "The headers" }
      end
    end

    it "renders the tab pattern, pairing panels with the enabled tabs" do
      doc = html(markup)

      element = doc.at("unmagic-tabs#response.UnmagicTabs")
      tabs = element.css("> [role=tablist] > [role=tab]")
      panels = element.css("> [role=tabpanel]")

      expect(tabs.map(&:text)).to eq(%w[Body Headers])
      expect(tabs.map { |tab| tab["aria-controls"] }).to eq(%w[response_panel_0 response_panel_1])
      expect(panels.map { |panel| panel["aria-labelledby"] }).to eq(%w[response_tab_0 response_tab_1])
      expect(panels.map(&:text)).to eq([ "The body", "The headers" ])
    end

    it "selects the active tab, keeps only it in the tab order, and hides the other panels" do
      doc = html(markup)

      expect(doc.css("[role=tab]").map { |tab| [ tab["aria-selected"], tab["tabindex"] ] }).to eq([ %w[false -1], %w[true 0] ])
      expect(doc.css("[role=tabpanel]").map { |panel| panel.key?("hidden") }).to eq([ true, false ])
    end

    it "shows a disabled tab's reason and gives it no role" do
      disabled = html(markup).at("[role=tablist] > [aria-disabled=true]")

      expect(disabled.name).to eq("span")
      expect(disabled.text).to eq("Preview (HTML only)")
    end

    it "selects the first tab by default and generates ids without an id:" do
      doc = html(view.tabs do |tabs|
        tabs.tab "One"
        tabs.tab "Two"
        tabs.panel { "1" }
        tabs.panel { "2" }
      end)

      expect(doc.at("unmagic-tabs")["id"]).to be_nil
      expect(doc.css("[role=tab]").map { |tab| tab["aria-selected"] }).to eq(%w[true false])
      expect(doc.at("[role=tab]")["id"]).to match(/\Aunmagic_tabs_\h{8}_tab_0\z/)
    end

    it "renders link tabs as navigation marking the current page" do
      doc = html(view.tabs do |tabs|
        tabs.tab "All", href: "/invitations", active: true
        tabs.tab "Replied", href: "/invitations?status=replied"
      end)

      expect(doc.at("unmagic-tabs")).to be_nil
      links = doc.css("nav.UnmagicTabs > .UnmagicTabs__list > a.UnmagicTabs__tab")
      expect(links.map { |link| [ link.text, link["aria-current"] ] }).to eq([ [ "All", "page" ], [ "Replied", nil ] ])
    end

    it "rejects mismatched panels and mixing links with panels" do
      expect { view.tabs { |tabs| tabs.tab "One" } }.to raise_error(ArgumentError, /1 enabled tabs but 0 panels/)
      expect do
        view.tabs do |tabs|
          tabs.tab "One", href: "/"
          tabs.panel { "x" }
        end
      end.to raise_error(ArgumentError, /can't mix href: tabs with panels/)
    end
  end

  describe "#copy_button" do
    it "renders an icon button that copies its text" do
      element = html(view.copy_button("deploy-key-0000", id: "copy_key")).at("unmagic-clipboard")

      expect(element["value"]).to eq("deploy-key-0000")
      expect(element["data-copied-label"]).to eq("Copied")

      button = element.at("> button")
      expect(button["id"]).to eq("copy_key")
      expect(button["type"]).to eq("button")
      expect(button["aria-label"]).to eq("Copy")
      expect(button["class"]).to eq("UnmagicButton UnmagicButton--icon UnmagicClipboard__button")
      expect(button.css("svg").map { |svg| svg["class"] }).to eq([ "UnmagicIcon UnmagicClipboard__idle", "UnmagicIcon UnmagicClipboard__done" ])
      expect(element.at("> [aria-live=polite]")).not_to be_nil
    end

    it "copies from an element by id, with block content as the label" do
      element = html(view.copy_button(from: "install_command") { "Copy command" }).at("unmagic-clipboard")

      expect(element["for"]).to eq("install_command")
      expect(element["value"]).to be_nil
      expect(element.at("button").text).to eq("Copy command")
      expect(element.at("button")["class"]).to eq("UnmagicButton UnmagicClipboard__button")
    end

    it "needs something to copy" do
      expect { view.copy_button }.to raise_error(ArgumentError, /copy_button needs the text to copy/)
    end
  end
end
