# frozen_string_literal: true

RSpec.describe "popovers, drawers, disclosures and scroll areas" do
  let(:view) { build_view }

  describe "#popover" do
    it "renders a trigger and a dialog panel with title, body and footer" do
      doc = html(view.popover("Rename", title: "Rename this", id: "rn", size: :wide, align: :end) do |popover|
        popover.footer { view.tag.button("Save") }
        "The form"
      end)

      element = doc.at("unmagic-popover#rn.UnmagicPopover")
      expect([ element["placement"], element["align"] ]).to eq(%w[bottom end])
      trigger = element.at("> button.UnmagicPopover__trigger")
      expect([ trigger["popovertarget"], trigger["aria-controls"], trigger.text.strip ]).to eq([ "rn_panel", "rn_panel", "Rename" ])
      expect(trigger.at("svg")).to be_present
      panel = element.at("> div#rn_panel")
      expect([ panel["popover"], panel["role"], panel["aria-labelledby"], panel["class"] ]).to eq([ "auto", "dialog", "rn_title", "UnmagicPopover__panel UnmagicPopover__panel--wide" ])
      expect(panel.at("h2#rn_title.UnmagicPopover__title").text).to eq("Rename this")
      expect(panel.at(".UnmagicPopover__body").text).to eq("The form")
      expect(panel.at(".UnmagicPopover__footer button").text).to eq("Save")
    end

    it "takes a trigger of its own, names an untitled panel by the label, and validates" do
      doc = html(view.popover("Ada", placement: :top) { |p| p.trigger { view.tag.img(src: "/ada.png") }; "Engineer" })
      expect(doc.at("button.UnmagicPopover__trigger--custom img")).to be_present
      expect(doc.at("[popover]")["aria-label"]).to eq("Ada")
      expect(doc.at("unmagic-popover")["placement"]).to eq("top")

      expect { view.popover { "x" } }.to raise_error(ArgumentError, /needs a label or a trigger/)
      expect { view.popover("x", placement: :left) { "x" } }.to raise_error(ArgumentError, /unknown popover placement/)
      expect { view.popover("x", align: :middle) { "x" } }.to raise_error(ArgumentError, /unknown popover align/)
    end
  end

  describe "drawers" do
    it "puts the side on the dialog box and the panel" do
      doc = html(view.dialog_tag("filters", title: "Filters", side: :end) { "Body" })

      dialog = doc.at("dialog#filters.UnmagicDialogBox")
      expect(dialog["data-side"]).to eq("end")
      panel = dialog.at(".UnmagicDialog")
      expect(panel["class"]).to eq("UnmagicDialog UnmagicDialog--drawer")
      expect(panel["data-side"]).to eq("end")

      centred = html(view.dialog_tag("help") { "Body" }).at("dialog")
      expect(centred["data-side"]).to be_nil
      expect(centred.at(".UnmagicDialog")["data-side"]).to be_nil
      expect { view.dialog_tag("x", side: :top) { "x" } }.to raise_error(ArgumentError, /unknown dialog side/)
    end

    it "carries a modal link's side for the skeleton" do
      link = html(view.modal_link_to("Details", "/jobs/1", side: :end)).at("a")
      expect([ link["data-turbo-frame"], link["data-unmagic-modal-side"] ]).to eq(%w[modal end])
      expect(html(view.modal_link_to("Details", "/jobs/1")).at("a")["data-unmagic-modal-side"]).to be_nil
    end
  end

  describe "#disclosure and #accordion" do
    it "renders a details with a leading chevron and the panel" do
      doc = html(view.disclosure("Advanced options", open: true, class: "mt-2") { "The options" })

      details = doc.at("details.UnmagicDisclosure")
      expect([ details.key?("open"), details["class"] ]).to eq([ true, "UnmagicDisclosure mt-2" ])
      summary = details.at("summary.UnmagicDisclosure__summary")
      expect(summary.children.map(&:name)).to eq(%w[svg span])
      expect(summary.at(".UnmagicDisclosure__title").text).to eq("Advanced options")
      expect(details.at(".UnmagicDisclosure__panel").text).to eq("The options")

      rich = html(view.disclosure { |d| d.summary { view.tag.b("Raw") }; "x" })
      expect(rich.at(".UnmagicDisclosure__title b").text).to eq("Raw")
      expect { view.disclosure { "x" } }.to raise_error(ArgumentError, /needs a summary/)
    end

    it "renders an accordion whose exclusive items share a name and trail their chevrons" do
      doc = html(view.accordion(id: "faq", exclusive: true) do |accordion|
        accordion.item("When am I charged?", open: true) { "Monthly." }
        accordion.item("Can I change plans?") { "Any time." }
      end)

      root = doc.at("div#faq.UnmagicAccordion")
      items = root.css("> details.UnmagicDisclosure.UnmagicDisclosure--in-accordion")
      expect(items.map { |d| [ d["name"], d.key?("open") ] }).to eq([ [ "faq", true ], [ "faq", false ] ])
      expect(items.first.at("summary").children.map(&:name)).to eq(%w[span svg])

      expect(html(view.accordion { |a| a.item("x") { "y" } }).at("details")["name"]).to be_nil
      expect(view.accordion { |_a| }).to be_blank
      expect do
        view.accordion(exclusive: true) { |a| a.item("x", open: true) { "1" }; a.item("y", open: true) { "2" } }
      end.to raise_error(ArgumentError, /only one item/)
    end
  end

  describe "#scroll_area" do
    it "is a scrolling box, a named region when labelled, with its height as a knob" do
      doc = html(view.scroll_area(max_height: "20rem", label: "Stages", class: "mt-1") { "Long" })

      area = doc.at("div.UnmagicScrollArea")
      expect(area["class"]).to eq("UnmagicScrollArea UnmagicScrollArea--y UnmagicScrollArea--shadows mt-1")
      expect([ area["role"], area["aria-label"], area["tabindex"], area["style"] ]).to eq([ "region", "Stages", "0", "--unmagic-scroll-area-max-height: 20rem" ])

      plain = html(view.scroll_area(axis: :x, shadows: false) { "Wide" }).at("div")
      expect(plain["class"]).to eq("UnmagicScrollArea UnmagicScrollArea--x")
      expect([ plain["role"], plain["tabindex"] ]).to eq([ nil, nil ])
      expect { view.scroll_area(axis: :z) { "x" } }.to raise_error(ArgumentError, /unknown scroll_area axis/)
    end
  end
end
