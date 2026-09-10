# frozen_string_literal: true

RSpec.describe Unmagic::Components::TableTag do
  let(:view) { build_view }

  it "renders headers and rows from plain arrays" do
    doc = html(view.table_tag([ "Name", "Score" ], [ [ "Ann", 42 ], [ "Bob", 7 ] ]))

    expect(doc.at("table")["class"]).to include("UnmagicTable")
    expect(doc.css("thead th").map(&:text)).to eq(%w[Name Score])
    expect(doc.css("tbody tr").map { |row| row.css("td").map(&:text) }).to eq([ %w[Ann 42], %w[Bob 7] ])
  end

  it "omits the thead when headers are absent" do
    expect(html(view.table_tag(nil, [ [ "Ann" ] ])).at("thead")).to be_nil
    expect(html(view.table_tag([], [ [ "Ann" ] ])).at("thead")).to be_nil
  end

  it "puts a cell hash's remaining keys on the cell" do
    doc = html(view.table_tag(nil, [ [ { content: "Ann", colspan: 2, class: "wide" } ] ]))

    expect(doc.at("td")["colspan"]).to eq("2")
    expect(doc.at("td")["class"]).to eq("wide")
  end

  it "puts a row hash's remaining keys on the tr" do
    doc = html(view.table_tag(nil, [ { cells: [ "Ann" ], id: "thing_1", class: "row" } ]))

    expect(doc.at("tr")["id"]).to eq("thing_1")
    expect(doc.at("tr")["class"]).to eq("row")
  end

  it "aligns a column's header and body cells alike" do
    doc = html(view.table_tag([ "Name", "Score" ], [ [ "Ann", 42 ] ], aligns: [ nil, :right ]))

    expect(doc.css("thead th").map { |th| th["class"] }).to eq([ nil, "is-right" ])
    expect(doc.css("tbody td").map { |td| td["class"] }).to eq([ nil, "is-right" ])
  end

  it "pins columns through a colgroup and switches to a fixed layout" do
    doc = html(view.table_tag([ "A", "B" ], [ [ 1, 2 ] ], widths: [ "40%", nil ]))

    expect(doc.at("table")["class"]).to include("UnmagicTable--fixed")
    expect(doc.css("col").map { |col| col["style"] }).to eq([ "width: 40%", nil ])
  end

  it "treats a non-length width as a class name, for a host's own utilities" do
    doc = html(view.table_tag([ "A" ], [ [ 1 ] ], widths: [ "w-[40%]" ]))

    expect(doc.at("col")["class"]).to eq("w-[40%]")
    expect(doc.at("col")["style"]).to be_nil
  end

  it "emits no colgroup when nothing is pinned" do
    doc = html(view.table_tag([ "A" ], [ [ 1 ] ]))

    expect(doc.at("colgroup")).to be_nil
    expect(doc.at("table")["class"]).not_to include("UnmagicTable--fixed")
  end

  it "renders a caption for screen readers only" do
    doc = html(view.table_tag([ "A" ], [ [ 1 ] ], caption: "Loading…"))

    expect(doc.at("caption").text).to eq("Loading…")
    expect(doc.at("caption")["class"]).to eq("UnmagicTable__caption")
  end
end
