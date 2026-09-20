# frozen_string_literal: true

RSpec.describe "sidebars, navbars, comboboxes and the command palette" do
  let(:view) { build_view(path: "/things") }

  describe "#sidebar" do
    it "renders a popover nav of sections with icons, badges and the current page" do
      doc = html(view.sidebar(id: "app_nav", label: "Main", class: "extra") do |nav|
        nav.header { "Acme" }
        nav.section do |s|
          s.link "Things", "/things", icon: :folder, badge: 3
          s.link "Inbox", "/inbox", badge: 0
        end
        nav.section("Settings", collapsible: true) { |s| s.link "Members", "/members" }
        nav.section("Help") { |s| s.link "Docs", "/docs", active: true }
        nav.footer { "Ada" }
      end)

      root = doc.at("unmagic-sidebar.UnmagicSidebar.UnmagicSidebar--below-lg.extra")
      nav = root.at("> nav#app_nav.UnmagicSidebar__panel")
      expect([ nav["aria-label"], nav["popover"] ]).to eq(%w[Main auto])
      expect(nav.at(".UnmagicSidebar__header").text).to eq("Acme")
      links = nav.css(".UnmagicSidebar__link")
      expect(links.map { |l| l.at(".UnmagicSidebar__text").text }).to eq(%w[Things Inbox Members Docs])
      expect(links[0]["aria-current"]).to eq("page")
      expect(links[0].at(".UnmagicSidebar__icon svg")).to be_present
      expect(links[0].at(".UnmagicBadge").text).to eq("3")
      expect(links[1].at(".UnmagicBadge")).to be_nil
      settings = nav.at("details.UnmagicSidebar__section")
      expect(settings.at("summary.UnmagicSidebar__title").text).to include("Settings")
      expect(settings.key?("open")).to be(false)
      help = nav.css("div.UnmagicSidebar__section").find { |d| d.at("h2") }
      expect(help.at("ul")["aria-labelledby"]).to eq(help.at("h2")["id"])
      expect(links[3]["aria-current"]).to eq("page")
      expect(nav.at(".UnmagicSidebar__footer").text).to eq("Ada")
    end

    it "opens a collapsible section holding the current page, renders the toggle, and validates" do
      doc = html(view.sidebar(id: "n") { |nav| nav.section("S", collapsible: true) { |s| s.link "Things", "/things" } })
      expect(doc.at("details").key?("open")).to be(true)

      toggle = html(view.sidebar_toggle("n")).at("button.UnmagicSidebarToggle")
      expect([ toggle["popovertarget"], toggle["aria-label"] ]).to eq(%w[n Menu])
      expect(html(view.sidebar(id: "n", collapse_below: :never) { |nav| nav.section { |s| s.link "x", "/" } }).at("nav")["popover"]).to be_nil
      expect { view.sidebar(id: "n", collapse_below: :xl) { |_n| } }.to raise_error(ArgumentError, /unknown sidebar collapse_below/)
    end
  end

  describe "#navbar" do
    it "renders a header with a brand, a folding nav of links and actions" do
      doc = html(view.navbar(label: "Main", sticky: true, collapse: :lg) do |nav|
        nav.brand("/") { "Acme" }
        nav.link "Jobs", "/jobs", current: true
        nav.link("/candidates") { "Candidates" }
        nav.actions { "Ada" }
      end)

      header = doc.at("header.UnmagicNavbar.UnmagicNavbar--sticky.UnmagicNavbar--collapse-lg")
      inner = header.at("> unmagic-navbar.UnmagicNavbar__inner")
      expect(inner.at("a.UnmagicNavbar__brand")["href"]).to eq("/")
      expect(inner.at("details.UnmagicNavbar__disclosure > summary.UnmagicNavbar__toggle")["aria-label"]).to eq("Menu")
      links = inner.css("nav.UnmagicNavbar__nav[aria-label=Main] ul.UnmagicNavbar__links > li > a.UnmagicNavbar__link")
      expect(links.map { |l| [ l.text, l["aria-current"] ] }).to eq([ [ "Jobs", "page" ], [ "Candidates", nil ] ])
      expect(inner.at(".UnmagicNavbar__actions").text).to eq("Ada")
    end

    it "has no toggle with collapse: false, and validates" do
      expect(html(view.navbar(collapse: false) { |nav| nav.link "x", "/" }).at("details")).to be_nil
      expect { view.navbar(collapse: :xl) { |_n| } }.to raise_error(ArgumentError, /unknown navbar collapse/)
    end
  end

  describe "#combobox_tag, FormBuilder#combobox and #combobox_results" do
    let(:members) { [ Struct.new(:id, :name).new(1, "Ada"), Struct.new(:id, :name).new(2, "Grace") ] }

    it "renders a single combobox with its hidden value, the ARIA pattern and the options" do
      doc = html(view.combobox_tag("owner_id", collection: members, text: :name, selected: 2, placeholder: "Anyone", id: "owner"))

      root = doc.at("unmagic-combobox#owner_combobox.UnmagicCombobox")
      expect(root.key?("multiple")).to be(false)
      input = root.at(".UnmagicCombobox__control > input.UnmagicCombobox__input")
      expect([ input["id"], input["role"], input["aria-expanded"], input["aria-autocomplete"], input["aria-controls"], input["value"], input["placeholder"] ]).to eq([ "owner", "combobox", "false", "list", "owner_combobox_listbox", "Grace", "Anyone" ])
      expect(root.at("input[type=hidden][name=owner_id]")["value"]).to eq("2")
      popup = root.at(".UnmagicCombobox__popup")
      expect(popup["popover"]).to eq("manual")
      options = popup.css("[role=listbox]#owner_combobox_listbox > [role=option]")
      expect(options.map { |o| [ o["id"], o["data-value"], o["data-label"], o["aria-selected"] ] }).to eq([ [ "owner_combobox_option_0", "1", "Ada", "false" ], [ "owner_combobox_option_1", "2", "Grace", "true" ] ])
      expect(options[0].at("svg.UnmagicCombobox__check")).to be_present
      expect(popup.at("[role=status]")).to be_present
    end

    it "renders chips and a blank input for multiple, rich options from a block, and a frame for src:" do
      doc = html(view.combobox_tag("label_ids", collection: members, text: :name, multiple: true, selected: [ 1 ], src: "/search", id: "labels") do |combobox, member|
        combobox.option member.id, label: member.name, keywords: "person" do
          view.tag.b(member.name)
        end
      end)

      root = doc.at("unmagic-combobox")
      expect([ root.key?("multiple"), root["src"], root["min-length"], root["debounce"] ]).to eq([ true, "/search", "1", "200" ])
      chip = root.at(".UnmagicCombobox__chips > li.UnmagicCombobox__chip")
      expect([ chip["data-value"], chip.at(".UnmagicCombobox__chip-label").text, chip.at("button.UnmagicCombobox__remove")["aria-label"], chip.at("input[type=hidden]")["name"] ]).to eq([ "1", "Ada", "Remove Ada", "label_ids[]" ])
      expect(root.at("input[data-unmagic-combobox-blank]")["name"]).to eq("label_ids[]")
      expect(root.at("[role=listbox]")["aria-multiselectable"]).to eq("true")
      expect(root.at("[role=option] b").text).to eq("Ada")
      expect(root.at("[role=option]")["data-keywords"]).to eq("person")
      expect(root.at("[role=listbox] turbo-frame")["id"]).to eq("labels_combobox_results")
      expect(root.at("[data-unmagic-combobox-searching]")).to be_present
    end

    it "works from the form builder as a field's control, and renders results for a search" do
      form = build_form_builder(Signup.new(name: "2"), view: view)
      doc = html(form.field(:name, "Owner", as: :combobox, collection: members, text: :name, required: true))
      input = doc.at(".UnmagicField input[role=combobox]")
      expect([ input["id"], input.key?("required"), input["value"] ]).to eq([ "signup_name", true, "Grace" ])
      expect(doc.at("input[type=hidden][name='signup[name]']")["value"]).to eq("2")
      expect(doc.at("label")["for"]).to eq("signup_name")

      results = html(view.combobox_results(members, text: :name))
      expect(results.css("[role=option]").map { |o| o["data-label"] }).to eq(%w[Ada Grace])
      framed = html(build_view(turbo_frame: "labels_combobox_results").combobox_results(members, text: :name))
      expect(framed.at("turbo-frame#labels_combobox_results [role=option]")["id"]).to eq("labels_combobox_option_0")
    end

    it "groups options" do
      doc = html(view.combobox_tag("x", id: "x") do |c|
        c.group("People") { c.option 1, label: "Ada" }
      end)
      group = doc.at("[role=group].UnmagicCombobox__group")
      expect(group.at(".UnmagicCombobox__group-label").text).to eq("People")
      expect(group["aria-labelledby"]).to eq(group.at(".UnmagicCombobox__group-label")["id"])
      expect(group.at("[role=option]")["data-label"]).to eq("Ada")
    end
  end

  describe "#command_palette" do
    it "renders a dialog holding an inline combobox of grouped commands" do
      doc = html(view.command_palette(src: "/commands", hotkey: "mod+k") do |palette|
        palette.group "Go to" do |group|
          group.link "Dashboard", "/", keywords: "home", shortcut: %w[G D], icon: :folder
          group.button "Sign out", "/session", method: :delete, hint: "now"
        end
      end)

      root = doc.at("unmagic-command-palette.UnmagicCommandPalette")
      expect(root["hotkey"]).to eq("mod+k")
      dialog = root.at("> dialog#command_palette.UnmagicDialogBox.UnmagicCommandPalette__dialog")
      expect([ dialog["aria-label"], dialog.key?("data-unmagic-dialog") ]).to eq([ "Command palette", true ])
      combobox = dialog.at("unmagic-combobox#command_palette_combobox.UnmagicCombobox--inline")
      expect([ combobox["mode"], combobox["src"], combobox["min-length"] ]).to eq(%w[activate /commands 2])
      input = combobox.at(".UnmagicCommandPalette__search input[role=combobox]")
      expect([ input["aria-expanded"], input.key?("autofocus") ]).to eq([ "true", true ])
      group = combobox.at("[role=listbox]#command_palette_combobox_listbox > [role=group]")
      expect(group.at(".UnmagicCombobox__group-label").text).to eq("Go to")
      options = group.css("[role=option].UnmagicCommandPalette__command")
      expect(options.map { |o| o["data-command"] }).to eq(%w[link button])
      link = options[0].at("a.UnmagicCommandPalette__target")
      expect([ link["href"], link["tabindex"], link.text.strip ]).to eq([ "/", "-1", "Dashboard" ])
      expect(options[0].at(".UnmagicCommandPalette__shortcut kbd.UnmagicKbd")).to be_present
      expect(options[1].at("form.UnmagicCommandPalette__form input[name=_method]")["value"]).to eq("delete")
      expect(options[1].at(".UnmagicCommandPalette__hint").text).to eq("now")
      expect(combobox.at("turbo-frame#command_palette_combobox_results")).to be_present
    end

    it "renders the trigger button and results, and needs something to search" do
      button = html(view.command_palette_button).at("button.UnmagicCommandPaletteButton")
      expect([ button["data-unmagic-dialog-open"], button["aria-haspopup"] ]).to eq(%w[command_palette dialog])
      expect(button.at("kbd.UnmagicKbd")).to be_present
      expect(button.text).to include("Search")

      results = html(build_view(turbo_frame: "command_palette_combobox_results").command_palette_results do |r|
        r.group("Issues") { |g| g.link "#12 Fix it", "/issues/12" }
      end)
      expect(results.at("turbo-frame#command_palette_combobox_results [role=group] [role=option] a")["href"]).to eq("/issues/12")

      expect { view.command_palette { |_p| } }.to raise_error(ArgumentError, /needs groups of commands/)
    end
  end
end
