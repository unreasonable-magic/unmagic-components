# frozen_string_literal: true

RSpec.describe "icons and avatars" do
  let(:view) { build_view }

  describe Unmagic::Components::Icons do
    it "renders a shipped Lucide glyph through unmagic-icon, hidden by default" do
      svg = html(described_class.svg(view, :circle_check, class: "extra")).at("svg")

      expect(svg["class"]).to eq("unmagic-icon UnmagicIcon extra")
      expect(svg["aria-hidden"]).to eq("true")
      expect(svg["data-unmagic-icon"]).to eq("unmagic_components:lucide/circle-check")
      expect(svg.at("circle")).not_to be_nil
    end

    it "carries no whitespace that would leak into a button's text" do
      expect(described_class.svg(view, :x)).not_to match(/\A\s|\s\z|>\s+</)
    end

    it "lets a caller override the defaults" do
      svg = html(described_class.svg(view, :check, "aria-hidden": "false", "aria-label": "Done")).at("svg")
      expect([ svg["aria-hidden"], svg["aria-label"] ]).to eq([ "false", "Done" ])
    end

    it "rejects a glyph the gem doesn't ship" do
      expect { described_class.svg(view, :unicorn) }.to raise_error(ArgumentError, /unknown icon :unicorn/)
    end

    it "ships every glyph a component names" do
      expect(described_class.names).to include(:wrench, :loader_circle, :shield_alert, :list_checks, :timer, :rotate_cw)
    end
  end

  describe "#avatar" do
    it "renders initials under a named image" do
      avatar = html(view.avatar("Ada Lovelace", src: "/ada.png")).at("span.UnmagicAvatar")

      expect(avatar["role"]).to eq("img")
      expect(avatar["aria-label"]).to eq("Ada Lovelace")
      expect(avatar["class"]).to include("UnmagicAvatar--medium")
      expect(avatar.at(".UnmagicAvatar__initials").text).to eq("AL")
      expect(avatar.at(".UnmagicAvatar__initials")["aria-hidden"]).to eq("true")
      image = avatar.at("img.UnmagicAvatar__image")
      expect([ image["src"], image["alt"], image["loading"] ]).to eq([ "/ada.png", "", "lazy" ])
    end

    it "takes the first and last words for initials" do
      expect(Unmagic::Components::Avatar.initials("Plato")).to eq("P")
      expect(Unmagic::Components::Avatar.initials("  ada   byron lovelace ")).to eq("AL")
    end

    it "has no image for a blank src" do
      expect(html(view.avatar("Ada", src: "")).at("img")).to be_nil
    end

    it "picks the same tint for the same name, however it's typed" do
      tint = ->(name) { html(view.avatar(name)).at("span")["class"][/UnmagicAvatar--tint-(\d)/, 1] }

      expect(tint.("Ada Lovelace")).to match(/\A[1-6]\z/)
      expect(tint.("ada  lovelace")).to eq(tint.("Ada Lovelace"))
    end

    it "is neutral with tint: false, and for a blank name" do
      expect(html(view.avatar("Ada", tint: false)).at("span")["class"]).not_to include("tint")

      blank = html(view.avatar("")).at("span.UnmagicAvatar")
      expect(blank["class"]).not_to include("tint")
      expect(blank["aria-label"]).to be_nil
      expect(blank.at(".UnmagicAvatar__initials").text).to eq("—")
    end

    it "passes other options to the root and takes shape and size" do
      avatar = html(view.avatar("Acme", shape: :square, size: :large, class: "extra", data: { id: 1 })).at("span")
      expect(avatar["class"]).to include("UnmagicAvatar--square", "UnmagicAvatar--large", "extra")
      expect(avatar["data-id"]).to eq("1")
    end

    it "renders a skeleton circle of the same size" do
      skeleton = html(view.avatar("Ada", size: :small, skeleton: true)).at(".UnmagicSkeleton--circle")
      expect(skeleton["style"]).to include("width: 1.5rem")
    end

    it "rejects an unknown size or shape" do
      expect { view.avatar("Ada", size: :huge) }.to raise_error(ArgumentError, /unknown avatar size :huge/)
      expect { view.avatar("Ada", shape: :blob) }.to raise_error(ArgumentError, /unknown avatar shape :blob/)
    end
  end

  describe "#avatar_group" do
    it "collapses past max into a counter naming the rest" do
      doc = html(view.avatar_group(max: 2, size: :small) do |group|
        [ "Ada Lovelace", "Grace Hopper", "Katherine Johnson", "Alan Turing" ].each { |name| group.avatar name }
      end)

      group = doc.at("div.UnmagicAvatarGroup")
      expect(group["role"]).to eq("group")
      expect(group["aria-label"]).to eq("4 people")
      expect(group.css(".UnmagicAvatar").size).to eq(2)
      expect(group.css(".UnmagicAvatar--small").size).to eq(2)
      more = group.at(".UnmagicAvatarGroup__more")
      expect([ more.text, more["title"] ]).to eq([ "+2", "Katherine Johnson, Alan Turing" ])
    end

    it "won't let one avatar change the group's size" do
      expect { view.avatar_group { |group| group.avatar "Ada", size: :large } }
        .to raise_error(ArgumentError, /takes the group's size/)
    end
  end
end
