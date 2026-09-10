# frozen_string_literal: true

RSpec.describe Unmagic::Components::Table do
  let(:view) { build_view }

  # A collection that knows a filter was applied, the way a search result set does.
  class FilteredCollection < Array
    def initialize(items = [], filtered: true)
      super(items)
      @filtered = filtered
    end

    def filtered? = @filtered
  end

  Pager = Struct.new(:previous, :next) do
    def page_url(direction) = "/things?page=#{direction == :previous ? 1 : 3}"
  end

  describe "chrome and cells" do
    it "renders the table with a dom id per row" do
      doc = html(view.table_for(things(2)) { |table| table.column("Name", :name) })

      expect(doc.at("table")["class"]).to include("UnmagicTable")
      expect(doc.css("tbody tr").map { |row| row["id"] }).to eq(%w[thing_1 thing_2])
      expect(doc.css("tbody td").map(&:text)).to eq([ "Thing 1", "Thing 2" ])
    end

    it "takes cell content from a block, which wins over an attribute" do
      doc = html(view.table_for(things(1)) do |table|
        table.column("Name", :name) { |thing| "block: #{thing.name}" }
      end)

      expect(doc.at("tbody td").text).to eq("block: Thing 1")
    end

    it "omits the thead when headers: false" do
      doc = html(view.table_for(things(1), headers: false) { |table| table.column("Name", :name) })

      expect(doc.at("thead")).to be_nil
      expect(doc.css("tbody tr").size).to eq(1)
    end

    it "marks numeric and aligned columns" do
      doc = html(view.table_for(things(1)) do |table|
        table.column("Name", :name)
        table.column("Score", :score, numeric: true)
        table.column("Mid", :score, align: :center)
        table.column("Extra", :score, align: :right, class: "px-2")
      end)

      expect(doc.css("thead th").map { |th| th["class"] })
        .to eq([ nil, "is-right", "is-center", "is-right" ])
      expect(doc.css("tbody td").map { |td| td["class"] })
        .to eq([ nil, "is-right is-numeric", "is-center", "is-right px-2" ])
    end

    it "adds a row_class per record" do
      doc = html(view.table_for(things(2), row_class: ->(thing) { "odd" if thing.id.odd? }) do |table|
        table.column("Name", :name)
      end)

      expect(doc.css("tbody tr").map { |row| row["class"] }).to eq([ "odd", nil ])
    end

    it "does not give a non-model row a dom id" do
      doc = html(view.table_for([ %w[Ann 42] ]) { |table| table.column("Name") { |row| row.first } })

      expect(doc.at("tbody tr")["id"]).to be_nil
    end
  end

  describe "empty states" do
    it "replaces the table with the blank slate" do
      doc = html(view.table_for([]) do |table|
        table.empty "No things yet."
        table.column("Name", :name)
      end)

      expect(doc.at("table")).to be_nil
      expect(doc.at(".UnmagicEmptyState").text).to eq("No things yet.")
    end

    it "falls back to a generic message" do
      expect(html(view.table_for([]) { |table| table.column("Name", :name) }).at(".UnmagicEmptyState").text)
        .to eq("Nothing here yet.")
    end

    it "takes a block" do
      doc = html(view.table_for([]) do |table|
        table.empty { view.link_to "Add one", "/things/new" }
        table.column("Name", :name)
      end)

      expect(doc.at(".UnmagicEmptyState a").text).to eq("Add one")
    end

    it "shows no_results instead when the collection reports it was filtered" do
      doc = html(view.table_for(FilteredCollection.new) do |table|
        table.empty "No things yet."
        table.no_results "Nothing matched."
        table.column("Name", :name)
      end)

      expect(doc.at(".UnmagicEmptyState").text).to eq("Nothing matched.")
    end

    it "falls back to a generic no-results message" do
      doc = html(view.table_for(FilteredCollection.new) do |table|
        table.empty "No things yet."
        table.column("Name", :name)
      end)

      expect(doc.at(".UnmagicEmptyState").text).to eq("No matching results.")
    end

    it "uses the empty slate when a filterable collection was not filtered" do
      doc = html(view.table_for(FilteredCollection.new([], filtered: false)) do |table|
        table.empty "No things yet."
        table.no_results "Nothing matched."
        table.column("Name", :name)
      end)

      expect(doc.at(".UnmagicEmptyState").text).to eq("No things yet.")
    end

    it "hands table.empty's extra options to the empty-state seam" do
      seen = nil
      Unmagic::Components.configure do |config|
        config.empty_state = ->(view, content, **options) do
          seen = options
          view.tag.p(content, class: "Custom")
        end
      end

      doc = html(view.table_for([]) { |table| table.empty "None.", icon: "tag" })

      expect(seen).to eq({ icon: "tag" })
      expect(doc.at("p.Custom").text).to eq("None.")
    end

    it "hands no_results options through too" do
      seen = nil
      Unmagic::Components.configure do |config|
        config.empty_state = ->(view, content, **options) { seen = options; view.tag.p(content) }
      end

      view.table_for(FilteredCollection.new) { |table| table.no_results "Nothing.", icon: "search" }

      expect(seen).to eq({ icon: "search" })
    end

    it "renders through a configured empty-state seam" do
      Unmagic::Components.configure do |config|
        config.empty_state = ->(view, content) { view.tag.p(content, class: "Custom") }
      end

      doc = html(view.table_for([]) { |table| table.empty "None." })

      expect(doc.at("p.Custom").text).to eq("None.")
    end
  end

  describe "sorting" do
    it "links a sortable header to its first direction" do
      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name, sort: :name) })

      link = doc.at("thead th a")
      expect(link["class"]).to eq("UnmagicTable__sort")
      expect(link["href"]).to eq("/things?direction=asc&sort=name")
      expect(doc.at("thead th")["aria-sort"]).to be_nil
    end

    it "toggles direction and marks the sorted column" do
      view = build_view(query: { "sort" => "name", "direction" => "asc" })
      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name, sort: :name) })

      expect(doc.at("thead th")["aria-sort"]).to eq("ascending")
      expect(doc.at("thead th a")["href"]).to include("direction=desc")
      expect(doc.at("thead th a span").text).to eq("↑")
      expect(doc.at("thead th a span")["aria-hidden"]).to eq("true")
    end

    it "honours a column's declared first direction" do
      doc = html(view.table_for(things(1)) do |table|
        table.column("Created", :score, sort: :created_at, direction: :desc)
      end)

      expect(doc.at("thead th a")["href"]).to include("direction=desc")
    end

    it "takes the applied sort from arguments when it is not in params" do
      doc = html(view.table_for(things(1), sorted_by: "name", sort_direction: :desc) do |table|
        table.column("Name", :name, sort: :name)
      end)

      expect(doc.at("thead th")["aria-sort"]).to eq("descending")
      expect(doc.at("thead th a")["href"]).to include("direction=asc")
    end

    it "preserves other query params and drops the page" do
      view = build_view(query: { "q" => "ada", "page" => "3" })
      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name, sort: :name) })

      href = doc.at("thead th a")["href"]
      expect(href).to include("q=ada")
      expect(href).not_to include("page=")
    end

    it "builds the URL from a sort_url lambda when given one" do
      doc = html(view.table_for(things(1), sort_url: ->(key, direction) { "/custom/#{key}/#{direction}" }) do |table|
        table.column("Name", :name, sort: :name)
      end)

      expect(doc.at("thead th a")["href"]).to eq("/custom/name/asc")
    end

    it "leaves an unsortable header as plain text" do
      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name) })

      expect(doc.at("thead th a")).to be_nil
      expect(doc.at("thead th").text).to eq("Name")
    end
  end

  describe "companion detail rows" do
    it "renders a second row under a record and drops the primary row's border" do
      doc = html(view.table_for(things(2)) do |table|
        table.column("Name", :name)
        table.details { |thing| "note for #{thing.name}" if thing.id == 1 }
      end)

      rows = doc.css("tbody tr")
      expect(rows.size).to eq(3)
      expect(rows[0]["class"]).to eq("has-details")
      expect(rows[1]["class"]).to include("UnmagicTable__details")
      expect(rows[1].at("td")["colspan"]).to eq("1")
      expect(rows[1].text).to include("note for Thing 1")
      expect(rows[2]["class"]).to be_nil
    end

    it "skips the companion row when the block captures nothing" do
      doc = html(view.table_for(things(2)) do |table|
        table.column("Name", :name)
        table.details { "" }
      end)

      expect(doc.css("tbody tr").size).to eq(2)
    end
  end

  describe "attributes" do
    it "puts anything else on the table element" do
      doc = html(view.table_for(things(1), class: "mb-6", data: { controller: "sortable" }) do |t|
        t.column("Name", :name)
      end)

      expect(doc.at("table")["class"]).to include("mb-6")
      expect(doc.at("table")["class"]).to include("UnmagicTable")
      expect(doc.at("table")["data-controller"]).to eq("sortable")
    end

    # id: is table_for's own option for the deferred frame, so it never reaches
    # the table element.
    it "keeps id: for the turbo frame rather than the table" do
      doc = html(view.table_for(things(1), defer: true, id: "labels") { |t| t.column("Name", :name) })

      expect(doc.at("turbo-frame")["id"]).to eq("labels")
      expect(doc.at("table")["id"]).to be_nil
    end

    it "carries them onto the skeleton too, so the deferred swap matches" do
      doc = html(view.table_for(things(1), defer: true, class: "mb-6") { |t| t.column("Name", :name) })

      expect(doc.at("table")["class"]).to include("mb-6")
    end
  end

  describe "widths" do
    it "pins columns identically for the skeleton and the loaded table" do
      loaded = html(view.table_for(things(1)) { |table| table.column("Name", :name, width: "40%") })

      deferred = build_view
      skeleton = html(deferred.table_for(things(1), defer: true) { |t| t.column("Name", :name, width: "40%") })

      expect(loaded.at("table")["class"]).to include("UnmagicTable--fixed")
      expect(skeleton.at("table")["class"]).to include("UnmagicTable--fixed")
      expect(loaded.css("col").map { |c| c["style"] }).to eq(skeleton.css("col").map { |c| c["style"] })
    end
  end

  describe "deferred loading" do
    it "renders a skeleton without touching the collection" do
      collection = Enumerator.new { raise "the collection was enumerated" }

      doc = html(view.table_for(collection, defer: true) do |table|
        table.column("Name", :name, width: "40%")
      end)

      frame = doc.at("turbo-frame")
      expect(frame["id"]).to eq("things_table")
      expect(frame["src"]).to eq("http://test.host/things")
      expect(doc.at("table")["aria-busy"]).to eq("true")
      expect(doc.at("table")["role"]).to eq("status")
      expect(doc.at("caption").text).to eq("Loading…")
      expect(doc.css(".UnmagicSkeleton").size).to eq(Unmagic::Components::Table::SKELETON_ROWS)
    end

    it "renders the real rows when the frame comes back for them" do
      view = build_view(turbo_frame: "things_table")
      doc = html(view.table_for(things(2), defer: true) { |table| table.column("Name", :name) })

      expect(doc.at("turbo-frame")["src"]).to be_nil
      expect(doc.css(".UnmagicSkeleton")).to be_empty
      expect(doc.css("tbody tr").size).to eq(2)
    end

    it "keeps sort links inside the frame" do
      view = build_view(turbo_frame: "things_table")
      doc = html(view.table_for(things(1), defer: true) { |table| table.column("Name", :name, sort: :name) })

      link = doc.at("thead th a")
      expect(link["data-turbo-frame"]).to eq("things_table")
      expect(link["data-turbo-action"]).to eq("advance")
    end

    it "uses an explicit frame id" do
      doc = html(view.table_for(things(1), defer: true, id: "custom") { |table| table.column("Name", :name) })

      expect(doc.at("turbo-frame")["id"]).to eq("custom")
    end
  end

  describe "pagination" do
    it "renders the pager the pagy_for seam resolves" do
      Unmagic::Components.configure do |config|
        config.pagy_for = ->(_view, _collection) { Pager.new(1, 3) }
      end

      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name) })

      nav = doc.at("nav.UnmagicPagination")
      expect(nav["aria-label"]).to eq("Pagination")
      expect(nav.css("a").map { |a| a["href"] }).to eq([ "/things?page=1", "/things?page=3" ])
    end

    it "disables an edge instead of linking it" do
      Unmagic::Components.configure { |config| config.pagy_for = ->(*) { Pager.new(nil, 3) } }

      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name) })

      expect(doc.css("nav a").size).to eq(1)
      expect(doc.at("nav span")["aria-disabled"]).to eq("true")
    end

    it "renders nothing on a single page" do
      Unmagic::Components.configure { |config| config.pagy_for = ->(*) { Pager.new(nil, nil) } }

      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name) })

      expect(doc.at("nav")).to be_nil
    end

    it "is suppressed by paginate: false" do
      Unmagic::Components.configure { |config| config.pagy_for = ->(*) { Pager.new(1, 3) } }

      doc = html(view.table_for(things(1), paginate: false) { |table| table.column("Name", :name) })

      expect(doc.at("nav")).to be_nil
    end

    it "accepts a pagy object passed straight in" do
      doc = html(view.table_for(things(1), paginate: Pager.new(1, 3)) { |table| table.column("Name", :name) })

      expect(doc.css("nav.UnmagicPagination a").size).to eq(2)
    end

    it "renders through a configured pagination seam" do
      Unmagic::Components.configure do |config|
        config.pagy_for = ->(*) { Pager.new(1, 3) }
        config.pagination = ->(view, pagy:, turbo_frame:) { view.tag.div("page #{pagy.next}", class: "Pager") }
      end

      doc = html(view.table_for(things(1)) { |table| table.column("Name", :name) })

      expect(doc.at("div.Pager").text).to eq("page 3")
    end
  end
end
