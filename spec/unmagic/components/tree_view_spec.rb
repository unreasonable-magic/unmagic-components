# frozen_string_literal: true

RSpec.describe "tree_view" do
  let(:view) { build_view }

  def files_tree(**options, &block)
    html(view.tree_view(label: "Files", **options) do |tree|
      tree.branch "app", icon: :folder do |app|
        app.branch "models", icon: :folder do |models|
          models.branch "concerns", icon: :folder do |concerns|
            concerns.leaf "named.rb", href: "/blob/app/models/concerns/named.rb", icon: :file
          end
          models.leaf "user.rb", href: "/blob/app/models/user.rb", icon: :file, current: true
          models.leaf "team.rb", href: "/blob/app/models/team.rb", icon: :file
        end
        app.branch "views", icon: :folder do |views|
          views.leaf "index.html.erb", icon: :file
        end
      end
      tree.leaf "Gemfile", href: "/blob/Gemfile", icon: :file
      block&.call(tree)
    end)
  end

  it "renders nested lists of details, labelled at the root" do
    root = files_tree.at("ul.UnmagicTree")

    expect(root["aria-label"]).to eq("Files")
    expect(root["class"]).to eq("UnmagicTree UnmagicTree--guides")
    expect(root["role"]).to be_nil

    app = root.at("> li.UnmagicTree__node > details.UnmagicTree__branch")
    summary = app.at("> summary.UnmagicTree__row")
    expect(summary.at(".UnmagicTree__label").text).to eq("app")
    expect(summary["title"]).to eq("app")
    expect(summary.css("svg").map { |svg| [ svg["class"], svg["aria-hidden"] ] }).to eq([
      [ "unmagic-icon UnmagicIcon UnmagicTree__toggle", "true" ], [ "unmagic-icon UnmagicIcon UnmagicTree__icon", "true" ]
    ])
    expect(app.at("> ul.UnmagicTree__children > li > details > summary .UnmagicTree__label").text).to eq("models")
  end

  it "nests to any depth" do
    root = files_tree.at("ul.UnmagicTree")

    expect(root.css("li.UnmagicTree__node").size).to eq(9)
    expect(root.css("ul.UnmagicTree__children ul.UnmagicTree__children ul.UnmagicTree__children a").map(&:text))
      .to eq([ "named.rb" ])
  end

  it "marks the current leaf and opens its ancestors, not their siblings" do
    root = files_tree.at("ul.UnmagicTree")

    current = root.at("a[aria-current=page]")
    expect(current.text).to eq("user.rb")
    expect(current["href"]).to eq("/blob/app/models/user.rb")
    expect(current["class"]).to eq("UnmagicTree__row UnmagicTree__row--leaf")
    expect(current.ancestors("details").map { |details| details.at("> summary").text }).to eq(%w[models app])
    expect(current.ancestors("details").all? { |details| details.key?("open") }).to be(true)

    closed = root.css("details").reject { |details| details.key?("open") }.map { |details| details.at("> summary").text }
    expect(closed).to eq(%w[concerns views])
  end

  it "lets an explicit open: win over a current leaf, either way" do
    root = html(view.tree_view(label: "Files") do |tree|
      tree.branch("shut", open: false) { |branch| branch.leaf "here.rb", current: true }
      tree.branch("open", open: true) { |branch| branch.leaf "there.rb" }
    end)

    expect(root.css("details").map { |details| details.key?("open") }).to eq([ false, true ])
  end

  it "renders a leaf without href: as text, and a leaf block as markup" do
    root = html(view.tree_view(label: "Teams") do |tree|
      tree.leaf "Platform"
      tree.leaf(href: "/teams/1") { view.safe_join([ "Design", view.badge(4) ], " ") }
    end)

    plain, linked = root.css("li > .UnmagicTree__row--leaf")
    expect(plain.name).to eq("span")
    expect(plain["title"]).to eq("Platform")
    expect(linked.name).to eq("a")
    expect(linked.at(".UnmagicTree__label .UnmagicBadge").text).to eq("4")
    expect(linked["title"]).to be_nil
  end

  it "keeps meta: whole at the end of a row, and puts other options on the row" do
    root = html(view.tree_view(label: "Files") do |tree|
      tree.branch "captures", meta: 20, class: "is-folder", title: "captures/"
      tree.leaf "brief.png", meta: "42 KB", data: { path: "captures/brief.png" }
    end)

    summary = root.at("summary")
    expect(summary["class"]).to eq("UnmagicTree__row is-folder")
    expect(summary["title"]).to eq("captures/")
    expect(summary.at(".UnmagicTree__meta").text).to eq("20")

    leaf = root.at(".UnmagicTree__row--leaf")
    expect(leaf.css("> span").map { |span| span["class"] }).to eq(%w[UnmagicTree__label UnmagicTree__meta])
    expect(leaf["data-path"]).to eq("captures/brief.png")
  end

  it "says Empty in a branch with nothing in it" do
    branch = html(view.tree_view(label: "Files") { |tree| tree.branch "tmp" }).at("details")

    expect(branch.at("ul")).to be_nil
    expect(branch.at("> p.UnmagicTree__empty").text).to eq("Empty")
  end

  it "passes options to the root, drops the guides on request, and renders nothing when empty" do
    root = files_tree(guides: false, id: "repo", class: "mt-2").at("ul")

    expect(root["id"]).to eq("repo")
    expect(root["class"]).to eq("UnmagicTree mt-2")
    expect(view.tree_view(label: "Files") { nil }).to be_nil
  end

  it "rejects a missing label and an unknown icon" do
    expect { view.tree_view(label: " ") { nil } }.to raise_error(ArgumentError, /needs a label/)
    expect { view.tree_view { nil } }.to raise_error(ArgumentError, /label/)
    expect { view.tree_view(label: "Files") { |tree| tree.leaf "x", icon: :nonexistent } }
      .to raise_error(ArgumentError, /unknown icon :nonexistent/)
  end
end
