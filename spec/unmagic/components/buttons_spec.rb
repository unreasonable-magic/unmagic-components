# frozen_string_literal: true

RSpec.describe "buttons, groups, separators, progress and spinners" do
  let(:view) { build_view }

  describe "#button" do
    it "renders a button with its variant, size, icon and label" do
      button = html(view.button("New label", :primary, size: :small, icon: :plus, id: "new")).at("button#new")

      expect(button["type"]).to eq("button")
      expect(button["class"]).to eq("UnmagicButton UnmagicButton--primary UnmagicButton--small")
      expect(button.at("svg.UnmagicButton__icon")["data-unmagic-icon"]).to eq("unmagic_components:lucide/plus")
      expect(button.at("span.UnmagicButton__label").text).to eq("New label")
    end

    it "renders a link with href:, and a button_to form with a method:" do
      link = html(view.button("Docs", href: "/docs")).at("a")
      expect([ link["href"], link["class"], link.text ]).to eq([ "/docs", "UnmagicButton", "Docs" ])

      doc = html(view.button("Delete", :danger, href: "/labels/1", method: :delete, form: { data: { turbo_confirm: "Sure?" } }))
      form = doc.at("form.UnmagicButton__form")
      expect(form["action"]).to eq("/labels/1")
      expect(form["data-turbo-confirm"]).to eq("Sure?")
      expect(form.at("input[name=_method]")["value"]).to eq("delete")
      expect(form.at("button")["class"]).to eq("UnmagicButton UnmagicButton--danger")
    end

    it "keeps an icon-only button's label for a screen reader" do
      button = html(view.button("Close", :icon, icon: :x)).at("button")

      expect([ button["aria-label"], button["title"] ]).to eq(%w[Close Close])
      expect(button.at(".UnmagicButton__label")).to be_nil
      expect(button.at("svg")).to be_present
    end

    it "is busy and disabled while loading, with a spinner in the icon's place" do
      button = html(view.button("Saving", :primary, loading: true, icon: :plus)).at("button")

      expect([ button["aria-busy"], button.key?("disabled") ]).to eq([ "true", true ])
      expect(button.at(".UnmagicSpinner.UnmagicButton__icon")["aria-hidden"]).to eq("true")
      expect(button.at("svg[data-unmagic-icon='unmagic_components:lucide/plus']")).to be_nil
    end

    it "disables a button, and marks a disabled link and takes it out of the tab order" do
      expect(html(view.button("x", disabled: true)).at("button").key?("disabled")).to be(true)

      link = html(view.button("x", href: "/", disabled: true)).at("a")
      expect([ link["aria-disabled"], link["tabindex"] ]).to eq([ "true", "-1" ])
    end

    it "fills the width with block:, takes a block as the label, and passes options through" do
      button = html(view.button(:default, block: true, class: "mt-2", type: "submit", data: { x: 1 }) { "Go" }).at("button")

      expect(button["class"]).to eq("UnmagicButton UnmagicButton--block mt-2")
      expect([ button["type"], button["data-x"], button.text ]).to eq([ "submit", "1", "Go" ])
    end

    it "rejects an unknown variant or size" do
      expect { view.button("x", :loud) }.to raise_error(ArgumentError, /unknown button variant :loud/)
      expect { view.button("x", size: :huge) }.to raise_error(ArgumentError, /unknown button size :huge/)
    end
  end

  describe "#button_group" do
    it "joins buttons and other items in a labelled group" do
      doc = html(view.button_group(label: "View", class: "mt-1") do |group|
        group.button "List", icon: :list_checks
        group.button "Board", href: "/board"
        group.item { view.tag.select(class: "mine") }
      end)

      group = doc.at("div[role=group]")
      expect([ group["aria-label"], group["class"] ]).to eq([ "View", "UnmagicButtonGroup mt-1" ])
      expect(group.children.map(&:name)).to eq(%w[button a select])
    end

    it "stacks with orientation: :vertical, renders nothing when empty, and rejects an unknown orientation" do
      vertical = html(view.button_group(orientation: :vertical) { |group| group.button "Up" }).at("div")
      expect(vertical["class"]).to eq("UnmagicButtonGroup UnmagicButtonGroup--vertical")
      expect(view.button_group { |_group| }).to be_blank
      expect { view.button_group(orientation: :diagonal) { |_g| } }.to raise_error(ArgumentError, /unknown button_group orientation/)
    end
  end

  describe "#separator" do
    it "is an hr when plain, a worded rule with a label, and upright when vertical" do
      expect(html(view.separator(class: "my-8")).at("hr")["class"]).to eq("UnmagicSeparator my-8")

      worded = html(view.separator("or")).at("div")
      expect([ worded["role"], worded.at("span.UnmagicSeparator__label").text ]).to eq([ "separator", "or" ])

      upright = html(view.separator(orientation: :vertical)).at("div")
      expect([ upright["role"], upright["aria-orientation"], upright["class"] ]).to eq([ "separator", "vertical", "UnmagicSeparator UnmagicSeparator--vertical" ])
      expect { view.separator(orientation: :slanted) }.to raise_error(ArgumentError, /unknown separator orientation/)
    end
  end

  describe "#progress" do
    it "renders a progress bar filled to the value's fraction of max" do
      bar = html(view.progress(3, max: 8, tone: :good, size: :small, label: "Uploaded", id: "up")).at("div#up")

      expect(bar["class"]).to eq("UnmagicProgress UnmagicProgress--small UnmagicProgress--good")
      expect([ bar["role"], bar["aria-label"], bar["aria-valuemin"], bar["aria-valuemax"], bar["aria-valuenow"] ])
        .to eq([ "progressbar", "Uploaded", "0", "8", "3.0" ])
      expect(bar.at(".UnmagicProgress__bar")["style"]).to eq("width: 37.5%")
    end

    it "clamps the value, names itself by default, and sweeps when there is no value" do
      expect(html(view.progress(140)).at(".UnmagicProgress__bar")["style"]).to eq("width: 100%")
      expect(html(view.progress(-3)).at(".UnmagicProgress__bar")["style"]).to eq("width: 0%")

      bar = html(view.progress).at("div")
      expect([ bar["aria-label"], bar["aria-valuenow"] ]).to eq([ "Progress", nil ])
      expect(bar["class"]).to include("UnmagicProgress--indeterminate")
      expect(bar.at(".UnmagicProgress__bar")["style"]).to be_nil
    end

    it "rejects an unknown tone, size or a max of nothing" do
      expect { view.progress(1, tone: :loud) }.to raise_error(ArgumentError, /unknown progress tone/)
      expect { view.progress(1, size: :huge) }.to raise_error(ArgumentError, /unknown progress size/)
      expect { view.progress(1, max: 0) }.to raise_error(ArgumentError, /max: must be positive/)
    end
  end

  describe "#spinner" do
    it "is a status with a hidden label, or with visible text, or decorative" do
      plain = html(view.spinner).at("span")
      expect([ plain["role"], plain["class"], plain.at(".UnmagicVisuallyHidden").text ]).to eq([ "status", "UnmagicSpinner UnmagicSpinner--medium", "Loading…" ])
      expect(plain.at("svg.UnmagicSpinner__ring")).to be_present

      texted = html(view.spinner("Checking DNS…", size: :small)).at("span")
      expect(texted.at(".UnmagicSpinner__text").text).to eq("Checking DNS…")
      expect(texted.at(".UnmagicVisuallyHidden")).to be_nil

      decorative = html(view.spinner(label: false)).at("span")
      expect([ decorative["role"], decorative["aria-hidden"] ]).to eq([ nil, "true" ])
      expect { view.spinner(size: :huge) }.to raise_error(ArgumentError, /unknown spinner size/)
    end
  end
end
