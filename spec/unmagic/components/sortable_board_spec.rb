# frozen_string_literal: true

RSpec.describe "sortable lists and boards" do
  let(:view) { build_view }

  # A record with a rank, as unmagic-sortable models have.
  let(:ranked) do
    Class.new(Thing) do
      attr_accessor :sortable_rank

      def self.name = "Thing"
    end
  end

  describe "#sortable_list" do
    it "renders its params and items, with the words it announces" do
      list = html(view.sortable_list(namespace: "cards", params: { column_id: 3 }, url: "/order", label: "To do",
        class: "extra") do |l|
        l.item(key: "a", rank: BigDecimal("1.5"), label: "First") { "One" }
        l.item(key: "b") { "Two" }
      end).at("unmagic-sortable-list")

      expect(list["class"]).to eq("UnmagicSortableList UnmagicSortableList--vertical extra")
      expect([ list["namespace"], list["url"], list["label"], list["orientation"] ]).to eq([ "cards", "/order", "To do", nil ])
      expect(list["data-sortable-picked"]).to eq("Picked up {item}. Position {position} of {count} in {list}.")
      expect(list["data-sortable-instructions"]).to include("Press Space to pick up")

      param = list.at("> unmagic-sortable-param")
      expect([ param["name"], param["value"] ]).to eq(%w[column_id 3])

      first, second = list.css("> unmagic-sortable-item")
      expect([ first["key"], first["data-sortable-rank"], first["data-sortable-label"], first.text ])
        .to eq([ "a", "1.5", "First", "One" ])
      expect(first["class"]).to eq("UnmagicSortableItem")
      expect([ second["data-sortable-rank"], second["data-sortable-label"] ]).to eq([ nil, nil ])
    end

    it "names a record through the sortable_item seam" do
      record = ranked.new(id: 7, name: "x").tap { |r| r.sortable_rank = BigDecimal("2.25") }
      item = html(view.sortable_list { |l| l.item(record) { "x" } }).at("unmagic-sortable-item")
      expect([ item["key"], item["data-sortable-rank"] ]).to eq(%w[7 2.25])

      Unmagic::Components.configure do |config|
        config.sortable_item = ->(_view, r) { { key: "signed-#{r.id}", rank: "9" } }
        config.sortable_url = ->(_view) { "/sortable/ordering" }
      end
      list = html(view.sortable_list { |l| l.item(record) { "x" } }).at("unmagic-sortable-list")
      expect(list["url"]).to eq("/sortable/ordering")
      expect(list.at("unmagic-sortable-item").then { |i| [ i["key"], i["data-sortable-rank"] ] }).to eq(%w[signed-7 9])
    end

    it "lets key: and rank: override the seam, and url: override the default" do
      Unmagic::Components.configuration.sortable_url = ->(_view) { "/default" }
      record = ranked.new(id: 7)
      list = html(view.sortable_list(url: "/mine") { |l| l.item(record, key: "own", rank: "4") { "x" } }).at("unmagic-sortable-list")

      expect(list["url"]).to eq("/mine")
      expect(list.at("unmagic-sortable-item")["key"]).to eq("own")
      expect(list.at("unmagic-sortable-item")["data-sortable-rank"]).to eq("4")
    end

    it "has no url when neither it nor the seam gives one" do
      expect(html(view.sortable_list).at("unmagic-sortable-list")["url"]).to be_nil
    end

    it "takes an orientation" do
      list = html(view.sortable_list(orientation: :grid)).at("unmagic-sortable-list")
      expect([ list["orientation"], list["class"] ]).to eq([ "grid", "UnmagicSortableList UnmagicSortableList--grid" ])
      expect { view.sortable_list(orientation: :diagonal) }
        .to raise_error(ArgumentError, /unknown sortable_list orientation :diagonal/)
    end

    it "needs a record or a key for each item" do
      expect { view.sortable_list { |l| l.item { "x" } } }.to raise_error(ArgumentError, /needs a record or a key/)
    end
  end

  describe "#sortable_handle" do
    it "is a labelled grip button" do
      handle = html(view.sortable_handle(class: "extra")).at("button")

      expect(handle.key?("data-sortable-handle")).to be(true)
      expect([ handle["type"], handle["aria-label"], handle["title"] ]).to eq([ "button", "Drag to reorder", "Drag to reorder" ])
      expect(handle["class"]).to eq("UnmagicButton UnmagicButton--icon UnmagicSortableHandle extra")
      expect(handle.at("svg")["data-unmagic-icon"]).to end_with("/grip-vertical")
      expect(html(view.sortable_handle(label: "Move Ada")).at("button")["aria-label"]).to eq("Move Ada")
    end
  end

  describe "#board" do
    def roadmap(**options)
      html(view.board(id: "roadmap", url: "/order", **options) do |b|
        b.column(key: "col-todo", rank: "1", title: "To do", params: { column: "todo" }) do |col|
          col.actions "ACTIONS"
          col.card(key: "card-1", rank: "1", label: "Write the brief") { "Write the brief" }
          col.card(key: "card-2", rank: "2", class: "extra") { "Book the room" }
          col.add url: "/cards", field: "card[title]", params: { "card[column]" => "todo" }
        end
        b.column(key: "col-done", rank: "2", title: "Done", params: { column: "done" }, count: 12)
        b.add_column url: "/columns", field: "column[name]"
      end)
    end

    it "renders a region with a sortable list of columns" do
      doc = roadmap(class: "extra", column_height: "30rem")
      board = doc.at("div#roadmap")

      expect(board["class"]).to eq("UnmagicBoard extra")
      expect([ board["role"], board["aria-label"] ]).to eq([ "region", "Board" ])
      expect(board["style"]).to eq("--unmagic-board-column-height: 30rem")

      columns = board.at("> unmagic-sortable-list.UnmagicBoard__columns")
      expect([ columns["namespace"], columns["orientation"], columns["url"] ]).to eq([ "roadmap-columns", "horizontal", "/order" ])

      todo, done = columns.css("> unmagic-sortable-item.UnmagicBoard__column")
      expect([ todo["key"], todo["data-sortable-rank"], todo["data-sortable-label"] ]).to eq([ "col-todo", "1", "To do" ])
      expect(done["key"]).to eq("col-done")
      expect(columns.at("> .UnmagicBoard__tail").key?("data-sortable-tail")).to be(true)
    end

    it "gives each column a handle header, a count, actions and a list of cards" do
      todo = roadmap.at("unmagic-sortable-item[key=col-todo]")
      panel = todo.at("> section.UnmagicBoard__panel")
      title = panel.at("h3.UnmagicBoard__title")

      expect(panel["aria-labelledby"]).to eq(title["id"])
      expect(title["id"]).to eq("roadmap_column_col-todo_title")
      expect(title.text).to eq("To do")

      head = panel.at("> header.UnmagicBoard__head")
      expect(head.key?("data-sortable-handle")).to be(true)
      grip = head.at("button.UnmagicBoard__grip")
      expect([ grip["aria-label"], grip.key?("data-sortable-handle") ]).to eq([ "Move To do", true ])
      expect(head.at(".UnmagicBoard__count").text).to eq("2 cards")
      expect(head.at(".UnmagicBoard__actions").text).to eq("ACTIONS")

      cards = panel.at("> unmagic-sortable-list.UnmagicBoard__cards")
      expect([ cards["namespace"], cards["url"], cards["label"] ]).to eq([ "roadmap-cards", "/order", "To do" ])
      expect(cards.at("> unmagic-sortable-param").then { |p| [ p["name"], p["value"] ] }).to eq(%w[column todo])
      first, second = cards.css("> unmagic-sortable-item")
      expect([ first["key"], first["class"], first["data-sortable-label"] ]).to eq([ "card-1", "UnmagicSortableItem UnmagicBoard__card", "Write the brief" ])
      expect(second["class"]).to eq("UnmagicSortableItem UnmagicBoard__card extra")
    end

    it "counts what it's told, singular or plural" do
      doc = roadmap
      expect(doc.at("unmagic-sortable-item[key=col-done] .UnmagicBoard__count").text).to eq("12 cards")
      one = html(view.board(id: "b") { |b| b.column(key: "c", title: "T") { |c| c.card(key: "x") { "x" } } })
      expect(one.at(".UnmagicBoard__count").text).to eq("1 card")
    end

    it "adds cards and columns through one-field forms" do
      doc = roadmap
      add = doc.at("unmagic-sortable-item[key=col-todo] details.UnmagicBoard__add")
      expect(add.at("summary.UnmagicBoard__addToggle").text).to eq("Add a card")

      form = add.at("form.UnmagicBoard__addForm")
      expect([ form["action"], form["method"], form.key?("data-board-add") ]).to eq([ "/cards", "post", true ])
      expect(form.at("input[type=hidden][name='card[column]']")["value"]).to eq("todo")
      field = form.at("unmagic-autogrow textarea[name='card[title]']")
      expect([ field["required"], field["aria-label"], field.key?("data-board-add-field") ]).to eq([ "required", "Add a card", true ])
      expect(field["id"]).to eq("roadmap_column_col-todo_add")
      expect(field["class"]).to include("UnmagicInput", "UnmagicBoard__addField")
      expect(form.at("button[type=submit]").text).to eq("Add card")
      expect(form.at("button[data-board-add-cancel]")["aria-label"]).to eq("Cancel")

      tile = doc.at(".UnmagicBoard__tail > details.UnmagicBoard__addColumn")
      expect(tile.at("summary").text).to eq("Add a list")
      expect(tile.at("form")["action"]).to eq("/columns")
      expect(tile.at("button[type=submit]").text).to eq("Add list")
      expect(tile.at("textarea")["id"]).to eq("roadmap_add_column")
    end

    it "can fix its columns in place, with no handles" do
      doc = html(view.board(id: "fixed", sortable_columns: false) { |b| b.column(title: "To do") { |c| c.card(key: "x") { "x" } } })

      expect(doc.at("#fixed > div.UnmagicBoard__columns > div.UnmagicBoard__column")).not_to be_nil
      expect(doc.at("[data-sortable-handle]")).to be_nil
      expect(doc.css("unmagic-sortable-list").map { |l| l["namespace"] }).to eq([ "fixed-cards" ])
    end

    it "takes a separate url for columns" do
      columns = html(view.board(id: "b", url: "/cards/order", columns_url: "/columns/order")).at("unmagic-sortable-list")
      expect(columns["url"]).to eq("/columns/order")
    end

    it "needs an id, and a key for a sortable column" do
      expect { view.board(id: nil) }.to raise_error(ArgumentError, /board needs an id/)
      expect { view.board(id: "b") { |b| b.column(title: "T") } }.to raise_error(ArgumentError, /needs a record or a key/)
    end
  end
end
