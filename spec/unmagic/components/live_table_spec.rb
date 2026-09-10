# frozen_string_literal: true

# A table whose rows a Turbo Stream keeps up to date: the columns live in a partial
# so the page render and a single broadcast row cannot drift.
RSpec.describe "live tables" do
  let(:view) { build_view }

  it "puts rows_id on the tbody so a stream can target it" do
    doc = html(view.table_for(things(2), rows_id: "thing_rows") { |table| table.column("Name", :name) })

    expect(doc.at("tbody")["id"]).to eq("thing_rows")
  end

  it "leaves the tbody unidentified by default" do
    doc = html(view.table_for(things(1)) { |table| table.column("Name", :name) })

    expect(doc.at("tbody")["id"]).to be_nil
  end

  it "takes its columns from a partial" do
    doc = html(view.table_for(things(2), columns: "things/columns"))

    expect(doc.css("thead th").map(&:text)).to eq(%w[Name Score])
    expect(doc.css("tbody tr").size).to eq(2)
    expect(doc.at("tbody td .name").text).to eq("Thing 1")
    expect(doc.css("col").first["style"]).to eq("width: 40%")
  end

  it "renders one row from the same partial, matching the table's own" do
    thing = things(1).first

    from_table = html(view.table_for([ thing ], columns: "things/columns")).at("tbody tr")
    on_its_own = html_row(view.row_for(thing, columns: "things/columns"))

    expect(on_its_own.at("tr")["id"]).to eq("thing_1")
    expect(on_its_own.at("tr").to_html).to eq(from_table.to_html)
  end

  # dom_id names the record's own class, so a table over an STI collection gets
  # ids that sort by type. A live table overrides them to keep one prefix.
  it "takes row ids from row_id: when given one" do
    doc = html(view.table_for(things(2), row_id: ->(t) { "thing_row_#{t.id}" }) do |table|
      table.column("Name", :name)
    end)

    expect(doc.css("tbody tr").map { |row| row["id"] }).to eq(%w[thing_row_1 thing_row_2])
  end

  it "uses the same row_id for a broadcast row" do
    doc = html_row(view.row_for(things(1).first, columns: "things/columns",
      row_id: ->(t) { "thing_row_#{t.id}" }))

    expect(doc.at("tr")["id"]).to eq("thing_row_1")
  end

  it "carries row_class onto a broadcast row" do
    thing = things(1).first
    doc = html_row(view.row_for(thing, columns: "things/columns", row_class: ->(t) { "score-#{t.score}" }))

    expect(doc.at("tr")["class"]).to eq("score-10")
  end

  it "renders the row's cells with the columns' own classes" do
    doc = html_row(view.row_for(things(1).first, columns: "things/columns"))

    expect(doc.css("td").map { |td| td["class"] }).to eq([ nil, "is-right is-numeric" ])
  end

  it "still accepts a block alongside the columns partial, for the empty state" do
    doc = html(view.table_for([], columns: "things/columns") { |table| table.empty "Nothing yet." })

    expect(doc.at(".UnmagicEmptyState").text).to eq("Nothing yet.")
  end
end
