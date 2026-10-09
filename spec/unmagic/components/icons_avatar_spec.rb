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

    it "is neutral with fill: false, and for a blank name" do
      expect(html(view.avatar("Ada", fill: false)).at("span")["class"]).not_to include("tint")

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

  describe "avatar initials" do
    it "reads a plain string as the kind it's told" do
      initials = ->(*args, **opts) { html(view.avatar(*args, **opts)).css(".UnmagicAvatar__initials").map(&:text) }

      expect(initials.call("Prince")).to eq([ "P" ])
      expect(initials.call("Prince", kind: :person)).to eq([ "PR" ])
      expect(initials.call("Kestrel Pty Ltd", kind: :organization)).to eq([ "KE" ])
      expect(initials.call("Ada Lovelace", initials: "🦄")).to eq([ "🦄" ])
      expect { view.avatar("Ada", kind: :robot) }.to raise_error(ArgumentError, /unknown avatar kind :robot/)
    end

    it "asks a name object for its own initials" do
      name = Struct.new(:to_s, :initials).new("Ada Lovelace", "AD")

      expect(html(view.avatar(name)).at(".UnmagicAvatar__initials").text).to eq("AD")
    end

    it "renders a longer mark beside the initials for the avatar's width to choose" do
      avatar = html(view.avatar("4K Gardens", kind: :organization)).at(".UnmagicAvatar")

      expect(avatar.at(".UnmagicAvatar__initials--long").text).to eq("4KG")
      expect(avatar.at(".UnmagicAvatar__initials--short").text).to eq("4K")
      expect(avatar.css("[aria-hidden=true]").size).to eq(2)
    end
  end

  describe "avatar fills" do
    after { Unmagic::Components.configuration.avatar_fill = nil }

    it "tints from the seed rather than the name when given one" do
      tint = ->(**opts) { html(view.avatar("Ada", **opts)).at("span")["class"][/tint-\d/] }

      expect(tint.call(seed: "user-1")).to eq(tint.call(seed: "user-1"))
      expect((1..20).map { |n| tint.call(seed: "user-#{n}") }.uniq.size).to be > 1
    end

    it "writes a gradient's colours to the avatar's custom properties" do
      avatar = html(view.avatar("Ada", seed: "019a", fill: Unmagic::Components::Avatar::Gradient.new)).at("span")

      expect(avatar["class"]).not_to include("tint")
      expect(avatar["style"]).to match(/--unmagic-avatar-background: linear-gradient\(135deg, #\h{6} 0%, #\h{6} 100%\);/)
      expect(avatar["style"]).to include("--unmagic-avatar-foreground: #ffffff;")
    end

    it "uses the configured fill, and the same colours outside a view" do
      Unmagic::Components.configure { |config| config.avatar_fill = Unmagic::Components::Avatar::Solid.new(lightness: 30) }
      fill = Unmagic::Components::Avatar.fill_for("019a")

      expect(fill.background).to match(/\A#\h{6}\z/)
      expect(html(view.avatar("Ada", seed: "019a")).at("span")["style"]).to include(fill.background)
    end

    it "takes any callable" do
      fill = ->(seed) { Unmagic::Components::Avatar::Fill.new(class_name: "brand-#{seed.length}") }

      expect(html(view.avatar("Ada", fill: fill)).at("span")["class"]).to include("brand-3")
    end

    it "keeps a caller's style alongside the fill's" do
      style = html(view.avatar("Ada", fill: Unmagic::Components::Avatar::Solid.new, style: "margin: 0")).at("span")["style"]

      expect(style).to include("--unmagic-avatar-background").and end_with("margin: 0")
    end
  end

  describe "avatar sizes and fit" do
    it "takes the larger named sizes and a CSS length" do
      expect(html(view.avatar("Ada", size: :xxlarge)).at("span")["class"]).to include("UnmagicAvatar--xxlarge")

      sized = html(view.avatar("Ada", size: "1.75rem")).at("span")
      expect(sized["class"]).to include("UnmagicAvatar--sized")
      expect(sized["style"]).to include("--unmagic-avatar-size: 1.75rem;")
      expect(html(view.avatar("Ada", size: "1.75rem", skeleton: true)).at(".UnmagicSkeleton--circle")["style"]).to include("1.75rem")
      expect { view.avatar("Ada", size: "big") }.to raise_error(ArgumentError, /unknown avatar size "big"/)
    end

    it "contains a logo" do
      expect(html(view.avatar("Acme", src: "/logo.svg", fit: :contain)).at("span")["class"]).to include("UnmagicAvatar--contain")
      expect { view.avatar("Acme", fit: :stretch) }.to raise_error(ArgumentError, /unknown avatar fit :stretch/)
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
