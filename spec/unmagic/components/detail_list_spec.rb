# frozen_string_literal: true

RSpec.describe Unmagic::Components::DetailList do
  let(:view) { build_view }

  it "pairs each item as a dt/dd in the inline layout" do
    markup = view.detail_list do |list|
      list.item "Name", "Ada"
      list.item "Role", "Engineer"
    end

    doc = html(markup)
    expect(doc.at("dl")["class"]).to eq("UnmagicDescriptionList")
    expect(doc.css("dt").map(&:text)).to eq(%w[Name Role])
    expect(doc.css("dd").map(&:text)).to eq(%w[Ada Engineer])
  end

  it "wraps each item and marks the list when stacked" do
    doc = html(view.detail_list(variant: :stacked) { |list| list.item "Name", "Ada" })

    expect(doc.at("dl")["class"]).to include("UnmagicDescriptionList--stacked")
    expect(doc.at("dl > div > dt").text).to eq("Name")
    expect(doc.at("dl > div > dd").text).to eq("Ada")
  end

  it "renders a blank value as an em dash but keeps a zero" do
    doc = html(view.detail_list do |list|
      list.item "Missing", nil
      list.item "Empty", ""
      list.item "Zero", 0
    end)

    expect(doc.css("dd").map(&:text)).to eq([ "—", "—", "0" ])
  end

  it "takes markup from a block" do
    doc = html(view.detail_list { |list| list.item("Site") { view.link_to "Home", "/" } })

    expect(doc.at("dd a").text).to eq("Home")
  end

  it "renders an em dash when a block captures nothing" do
    doc = html(view.detail_list { |list| list.item("Nothing") { "" } })

    expect(doc.at("dd").text).to eq("—")
  end

  it "adds class: to the dl and to an item's dd, and spans a full-width item" do
    doc = html(view.detail_list(variant: :stacked, class: "mt-4") do |list|
      list.item "Wide", "value", class: "font-mono", span: :full
    end)

    expect(doc.at("dl")["class"]).to include("mt-4")
    expect(doc.at("dd")["class"]).to eq("font-mono")
    expect(doc.at("dl > div")["class"]).to eq("is-full")
  end

  it "rejects an unknown variant" do
    expect { view.detail_list(variant: :boxed) { |list| list.item "a", "b" } }
      .to raise_error(ArgumentError, /unknown detail_list variant :boxed/)
  end
end
