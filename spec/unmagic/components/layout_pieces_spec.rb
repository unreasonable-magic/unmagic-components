# frozen_string_literal: true

RSpec.describe "sections, items and charts" do
  let(:view) { build_view }

  describe "#section" do
    it "renders a heading with its aside and actions, then the body" do
      doc = html(view.section("Files", spacing: :tight, heading: :h3, id: "files") do |section|
        section.aside { view.badge("12") }
        section.actions { view.tag.button("Upload") }
        "The list"
      end)

      root = doc.at("section#files")
      expect(root["class"]).to eq("UnmagicSection UnmagicSection--tight")
      expect(root.at(".UnmagicSection__head .UnmagicSection__heading > h3.UnmagicSection__title").text).to eq("Files")
      expect(root.at(".UnmagicSection__heading .UnmagicBadge").text).to eq("12")
      expect(root.at(".UnmagicSection__actions button").text).to eq("Upload")
      expect(root.children.last.text).to eq("The list")
    end

    it "leaves out the actions when none, and rejects an unknown spacing" do
      expect(html(view.section("Files") { "x" }).at(".UnmagicSection__actions")).to be_nil
      expect { view.section("x", spacing: :huge) { "x" } }.to raise_error(ArgumentError, /unknown section spacing/)
    end
  end

  describe "#item" do
    it "renders media, a linked title with meta, a description, the body and actions" do
      doc = html(view.item(title: "cat.png", description: "image/png · 12 KB", href: "/files/1", mono: true, class: "row") do |item|
        item.media { view.tag.img(src: "/cat.png") }
        item.meta { view.badge("Hidden") }
        item.actions { view.tag.button("More") }
        "Under the description"
      end)

      root = doc.at("div.UnmagicItem")
      expect(root["class"]).to eq("UnmagicItem UnmagicItem--link UnmagicItem--mono row")
      expect(root.at(".UnmagicItem__media img")["src"]).to eq("/cat.png")
      title = root.at(".UnmagicItem__heading > a.UnmagicItem__title")
      expect([ title.text, title["href"] ]).to eq([ "cat.png", "/files/1" ])
      expect(root.at(".UnmagicItem__heading .UnmagicBadge").text).to eq("Hidden")
      expect(root.at(".UnmagicItem__description").text).to eq("image/png · 12 KB")
      expect(root.at(".UnmagicItem__main").text).to include("Under the description")
      expect(root.at(".UnmagicItem__actions button").text).to eq("More")
    end

    it "is a plain span title without href, and takes title and description blocks" do
      root = html(view.item { |item| item.title { view.tag.code("x") }; item.description "y" }).at(".UnmagicItem")

      expect(root.at("span.UnmagicItem__title code").text).to eq("x")
      expect(root.at(".UnmagicItem__media")).to be_nil
      expect(root.at(".UnmagicItem__actions")).to be_nil
    end
  end

  describe "#chart" do
    let(:days) { (Date.new(2026, 9, 1)..Date.new(2026, 9, 7)).to_a }
    let(:series) do
      [
        { label: "Suno", values: days.each_with_object({}) { |d, h| h[d] = d.day * 2 }, total: 56 },
        { label: "ElevenLabs", values: days.each_with_object({}) { |d, h| h[d] = d.day }, total: 28 }
      ]
    end

    it "draws stacked columns with a legend, tooltips, gridlines and a table of the numbers" do
      doc = html(view.chart(series, labels: days, title: "Spend", format: :money, id: "spend"))

      figure = doc.at("figure#spend.UnmagicChart.UnmagicChart--column")
      expect(figure.at("figcaption .UnmagicChart__title").text).to eq("Spend")
      legend = figure.css(".UnmagicChart__legend > li")
      expect(legend.map(&:text).map(&:squish)).to eq([ "Suno · $56", "ElevenLabs · $28" ])
      expect(legend.map { |li| li.at(".UnmagicChart__swatch")["class"] }).to eq(%w[UnmagicChart__swatch\ UnmagicChart__swatch--1 UnmagicChart__swatch\ UnmagicChart__swatch--2])

      svg = figure.at("svg.UnmagicChart__svg")
      expect([ svg["role"], svg["aria-label"], svg["viewBox"] ]).to eq([ "img", "Spend", "0 0 720 200" ])
      expect(svg.css("line.UnmagicChart__grid").size).to eq(2)
      expect(svg.css("line.UnmagicChart__axis").size).to eq(1)
      columns = svg.css("g.UnmagicChart__column")
      expect(columns.size).to eq(7)
      expect(columns.first.at("title").text).to eq("1 Sep\n$1.00 ElevenLabs\n$2.00 Suno")
      expect(columns.first.css("path.UnmagicChart__mark").map { |p| p["class"] }).to eq([ "UnmagicChart__mark UnmagicChart__mark--1", "UnmagicChart__mark UnmagicChart__mark--2" ])
      expect(svg.css("text").map(&:text)).to include("$0", "$20", "$40", "7 Sep")

      table = figure.at("details.UnmagicChart__table table.UnmagicTable")
      expect(table.css("thead th").map(&:text)).to eq(%w[Label Suno ElevenLabs])
      expect(table.css("tbody tr").size).to eq(7)
      expect(table.at("tbody tr td:nth-child(2)").text).to eq("$2.00")
    end

    it "draws a line with gaps and a dot on the newest reading, and takes array values and a label format" do
      times = (0..4).map { |i| Time.utc(2026, 9, 1, 12, i * 10) }
      doc = html(view.chart([ { label: "CPU", values: [ 20, 40, nil, 60, 80 ] } ], labels: times, type: :line, format: :percent, max: 100,
        legend: false, table: false, label_format: ->(t) { t.strftime("%H:%M") }))

      svg = doc.at("figure.UnmagicChart--line svg")
      expect(doc.at("figcaption")).to be_nil
      expect(doc.at("details")).to be_nil
      path = svg.at("path.UnmagicChart__line--1")["d"]
      expect(path.scan("M").size).to eq(2)
      expect(svg.at("circle.UnmagicChart__dot--1")["cy"].to_f).to be < 60
      expect(svg.css("g.UnmagicChart__column title").map(&:text)[2]).to eq("12:20\nno reading CPU")
      expect(svg.css("text").map(&:text)).to include("0%", "50%", "100%", "12:00", "12:40")
    end

    it "reads counts as sizes, rejects bad input, and draws an axis for a chart of nothing" do
      chart = Unmagic::Components::Chart.new(view, [ { label: "x", values: {} } ], labels: [])
      expect([ chart.reading(1500), chart.reading(999), chart.reading(2_400_000) ]).to eq([ "1.5K", "999", "2.4M" ])
      expect(html(view.chart([ { label: "x", values: {} } ], labels: [ "a" ])).css("svg text").map(&:text)).to include("0", "1")

      expect { view.chart([], labels: []) }.to raise_error(ArgumentError, /at least one series/)
      expect { view.chart([ { label: "x", values: {} } ], labels: [], type: :pie) }.to raise_error(ArgumentError, /unknown chart type/)
      expect { view.chart([ { label: "x", values: {} } ], labels: [], format: :bytes) }.to raise_error(ArgumentError, /unknown chart format/)
    end
  end

  describe "table cells on a phone" do
    it "carry their heading as data-label" do
      doc = html(view.table_tag([ "Name", { content: view.tag.a("Score", href: "#") } ], [ [ "Ann", 42 ], { cells: [ { content: "x", colspan: 2 } ] } ]))

      expect(doc.css("tbody tr").first.css("td").map { |td| td["data-label"] }).to eq(%w[Name Score])
      expect(doc.css("tbody tr").last.at("td")["data-label"]).to be_nil
      expect(html(view.table_tag(nil, [ [ "a" ] ])).at("td")["data-label"]).to be_nil
    end
  end
end
