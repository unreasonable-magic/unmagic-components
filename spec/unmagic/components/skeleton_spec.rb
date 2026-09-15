# frozen_string_literal: true

RSpec.describe "skeletons" do
  let(:view) { build_view }

  describe "shapes" do
    it "renders a text line as a line box holding a bar, hidden from assistive technology" do
      line = html(view.skeleton_text(width: "60%")).at("span.UnmagicSkeletonLine")
      bar = line.at("> span")

      expect(line["aria-hidden"]).to eq("true")
      expect(bar["class"]).to eq("UnmagicSkeleton UnmagicSkeleton--text")
      expect(bar["style"]).to eq("width: 60%")
    end

    it "renders a paragraph of lines with a shorter last line" do
      text = html(view.skeleton_text(lines: 3, width: "80%")).at("span.UnmagicSkeletonText")
      bars = text.css("> .UnmagicSkeletonLine > .UnmagicSkeleton--text")

      expect(text["style"]).to eq("width: 80%")
      expect(text["aria-hidden"]).to eq("true")
      expect(bars.map { |bar| bar["style"] }).to eq([ nil, nil, "width: 60%" ])
    end

    it "sizes a circle, a block and a button" do
      circle = html(view.skeleton_circle(size: "3rem")).at("span")
      block = html(view.skeleton_block).at("span")
      button = html(view.skeleton_button(size: :small)).at("span")

      expect(circle["style"]).to eq("width: 3rem; height: 3rem")
      expect([ block["class"], block["style"] ]).to eq([ "UnmagicSkeleton UnmagicSkeleton--block", "height: 8rem" ])
      expect(button["class"]).to eq("UnmagicSkeleton UnmagicSkeleton--button UnmagicSkeleton--small")
    end

    it "puts class: and style: on the line, and width: on its bar" do
      line = html(view.skeleton_text(width: "50%", class: "mt-2", style: "opacity: 0.5")).at("span")

      expect(line["class"]).to eq("UnmagicSkeletonLine mt-2")
      expect(line["style"]).to eq("opacity: 0.5")
      expect(line.at("> span")["style"]).to eq("width: 50%")
    end

    it "adds classes and appends styles to the other shapes" do
      block = html(view.skeleton_block(height: "4rem", class: "mt-2", style: "opacity: 0.5")).at("span")

      expect(block["class"]).to eq("UnmagicSkeleton UnmagicSkeleton--block mt-2")
      expect(block["style"]).to eq("height: 4rem; opacity: 0.5")
    end

    it "rejects no lines and an unknown button size" do
      expect { view.skeleton_text(lines: 0) }.to raise_error(ArgumentError, /at least one line/)
      expect { view.skeleton_button(size: :huge) }.to raise_error(ArgumentError, /unknown skeleton button size :huge/)
    end
  end

  describe "#skeleton" do
    it "yields the shapes as a builder and announces the group once" do
      doc = html(view.skeleton(label: "Loading candidate", class: "profile") do |s|
        view.safe_join [ s.circle(size: "3rem"), s.text(width: "60%"), s.text(lines: 2), s.block(height: "4rem"), s.button ]
      end)

      group = doc.at("div.UnmagicSkeletonGroup.profile")
      expect(group["role"]).to eq("status")
      expect(group.at("> .UnmagicVisuallyHidden").text).to eq("Loading candidate")
      expect(group.css(".UnmagicSkeleton").size).to eq(6)
    end

    it "says Loading… by default" do
      expect(html(view.skeleton { |s| s.text }).at(".UnmagicVisuallyHidden").text).to eq("Loading…")
    end
  end

  describe "skeleton: true" do
    it "keeps a detail list's labels and stands bars in for its values" do
      doc = html(view.detail_list(skeleton: true) do |list|
        list.item "Created", "ignored"
        list.item "Salary"
      end)

      group = doc.at("div.UnmagicSkeletonGroup[role=status]")
      expect(group.css("dt").map(&:text)).to eq(%w[Created Salary])
      expect(group.css("dd").map { |dd| dd.at(".UnmagicSkeleton--text")["style"] }).to eq([ "width: 55%", "width: 40%" ])
      expect(group.at("dd").text).to eq("")
    end

    it "blocks out a page header, keeping whatever is given" do
      header = html(view.page_header(skeleton: true, back: { text: "Labels", path: "/labels" })).at("header")

      expect(header["role"]).to eq("status")
      expect(header.at("> .UnmagicVisuallyHidden").text).to eq("Loading…")
      expect(header.at(".UnmagicPageHeader__back").text).to eq("Labels")
      expect(header.at("h1 .UnmagicSkeleton--text")).not_to be_nil
      expect(header.at(".UnmagicPageHeader__description .UnmagicSkeleton--text")).not_to be_nil
      expect(header.at(".UnmagicPageHeader__actions .UnmagicSkeleton--button")).not_to be_nil
    end

    it "renders a skeleton header's real title and actions, and can leave out the description" do
      doc = html(view.page_header(title: "Labels", description: false, skeleton: true) { view.tag.button("New") })

      expect(doc.at("h1").text).to eq("Labels")
      expect(doc.at(".UnmagicPageHeader__description")).to be_nil
      expect(doc.at(".UnmagicPageHeader__actions button").text).to eq("New")
    end

    it "keeps a card's title and fills an empty body with lines" do
      card = html(view.card(title: "Members", skeleton: true)).at("section.UnmagicCard")

      expect(card["role"]).to eq("status")
      expect(card.at(".UnmagicCard__title").text).to eq("Members")
      expect(card.css(".UnmagicCard__body .UnmagicSkeleton--text").size).to eq(3)
    end

    it "lets a skeleton card's body be blocked out by hand" do
      card = html(view.card(skeleton: true) { view.skeleton_block(height: "4rem") }).at("section")

      expect(card.at(".UnmagicCard__body .UnmagicSkeleton--block")).not_to be_nil
      expect(card.css(".UnmagicSkeleton--text")).to be_empty
    end

    it "leaves the components unchanged without it" do
      expect(html(view.card(title: "Members") { "Body" }).at("section")["role"]).to be_nil
      expect(html(view.page_header(title: "Labels")).at(".UnmagicSkeleton")).to be_nil
    end
  end
end
