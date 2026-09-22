# frozen_string_literal: true

RSpec.describe "toasts" do
  let(:view) { build_view }

  # Nokogiri doesn't expose a <template>'s content as children, so read each
  # toast out of the markup directly.
  def toasts(markup)
    markup.to_s.scan(%r{<template data-unmagic-toast-template="">(.*?)</template>}m).map do |(inner)|
      Nokogiri::HTML5.fragment(inner).at(".UnmagicToast")
    end
  end

  describe "#flash_toasts" do
    # 0 is what the element reads as "keep it up until it is dismissed", so it has to survive as
    # the literal attribute rather than being dropped as a blank or falling back to the default.
    it "passes a duration of 0 through for a toast that waits to be dismissed" do
      doc = html(view.flash_toasts({}, duration: 0))

      expect(doc.at("unmagic-toasts")["duration"]).to eq("0")
    end

    it "mounts the element around a permanent, live stack" do
      doc = html(view.flash_toasts({}, duration: 8000))

      element = doc.at("unmagic-toasts#unmagic_toasts")
      expect(element["duration"]).to eq("8000")

      stack = element.at("> .UnmagicToasts__stack")
      expect(stack["id"]).to eq("unmagic_toasts_stack")
      expect(stack["data-turbo-permanent"]).to eq("")
      expect(stack["popover"]).to eq("manual")
      expect(stack["aria-live"]).to eq("polite")
    end

    it "renders a template per flash, toned by its type" do
      found = toasts(view.flash_toasts({ "notice" => "Saved.", "alert" => "Couldn't save.", "custom" => "Hello" }))

      expect(found.map { |toast| toast.at(".UnmagicToast__message").text }).to eq([ "Saved.", "Couldn't save.", "Hello" ])
      expect(found.map { |toast| toast["class"] }).to eq(
        [ "UnmagicToast UnmagicToast--good", "UnmagicToast UnmagicToast--bad", "UnmagicToast UnmagicToast--info" ]
      )
    end

    it "interrupts only for a bad toast" do
      good, bad = toasts(view.flash_toasts({ "notice" => "Saved.", "alert" => "Couldn't save." }))

      expect(good["role"]).to be_nil
      expect(bad["role"]).to eq("alert")
    end

    it "renders each message of an array and skips blank ones" do
      found = toasts(view.flash_toasts({ "notice" => [ "One", "", "Two" ], "alert" => nil }))

      expect(found.map { |toast| toast.at(".UnmagicToast__message").text }).to eq(%w[One Two])
    end

    it "escapes the message" do
      toast = toasts(view.flash_toasts({ "notice" => "<b>bold</b>" })).first

      expect(toast.at(".UnmagicToast__message b")).to be_nil
      expect(toast.at(".UnmagicToast__message").text).to eq("<b>bold</b>")
    end

    it "gives each toast a labelled dismiss button" do
      button = toasts(view.flash_toasts({ "notice" => "Saved." })).first.at("button")

      expect(button["type"]).to eq("button")
      expect(button["aria-label"]).to eq("Dismiss")
      expect(button["data-unmagic-toast-dismiss"]).to eq("")
    end

    it "follows configured flash tones" do
      Unmagic::Components.configure { |config| config.flash_tones = { "notice" => :warn } }

      expect(toasts(view.flash_toasts({ "notice" => "Heads up." })).first["class"]).to include("UnmagicToast--warn")
    end

    it "rejects an unknown tone" do
      Unmagic::Components.configure { |config| config.flash_tones = { "notice" => :loud } }

      expect { view.flash_toasts({ "notice" => "Hi" }) }.to raise_error(ArgumentError, /unknown toast tone :loud/)
    end
  end

  describe "turbo_stream.toast" do
    it "appends a toast template to the toasts element" do
      markup = Turbo::Streams::TagBuilder.new(view).toast("Invitation sent.", tone: :warn).to_s
      stream = Nokogiri::HTML5.fragment(markup).at("turbo-stream")

      expect(stream["action"]).to eq("append")
      expect(stream["target"]).to eq("unmagic_toasts")
      expect(toasts(markup).first["class"]).to eq("UnmagicToast UnmagicToast--warn")
      expect(toasts(markup).first.at(".UnmagicToast__message").text).to eq("Invitation sent.")
    end

    it "defaults to a good toast" do
      markup = Turbo::Streams::TagBuilder.new(view).toast("Copied.").to_s

      expect(toasts(markup).first["class"]).to include("UnmagicToast--good")
    end
  end
end

RSpec.describe "toast options and composition" do
  let(:view) { build_view }

  def toast_node(**options, &block)
    builder = Unmagic::Components::Toast.new(view, "Message", **options)
    block.call(builder) if block
    html(builder.render).at(".UnmagicToast")
  end

  it "renders a sticky, positioned, titled toast with root options" do
    node = toast_node(duration: 0, position: :bottom_start, title: "<b>Title</b>",
      width: 440, layout: :vertical, id: "saved", class: "custom", data: { project: 1 })
    expect(node["data-duration"]).to eq("0")
    expect(node["data-position"]).to eq("bottom_start")
    expect(node["data-layout"]).to eq("vertical")
    expect(node["style"]).to include("--unmagic-toast-width: 440px")
    expect(node["id"]).to eq("saved")
    expect(node["class"]).to include("custom")
    expect(node["data-project"]).to eq("1")
    expect(node.at(".UnmagicToast__title").text).to eq("<b>Title</b>")
    expect(node.at(".UnmagicToast__title b")).to be_nil
  end

  it "hides only the built-in close button when requested" do
    node = toast_node(close_button: false, duration: 0) do |toast|
      toast.actions { view.tag.button("Dismiss", data: { unmagic_toast_dismiss: "" }) }
    end
    expect(node.at(".UnmagicToast__dismiss")).to be_nil
    expect(node.at(".UnmagicToast__actions [data-unmagic-toast-dismiss]").text).to eq("Dismiss")
    expect(node["data-duration"]).to eq("0")
    expect(node["close_button"]).to be_nil
    expect(node.text).to eq("MessageDismiss")
    expect(toast_node.at(".UnmagicToast__dismiss")).not_to be_nil
    expect(toast_node(close_button: true).at(".UnmagicToast__dismiss")).not_to be_nil
  end

  it "forwards close_button through the stream API without changing the timer" do
    markup = Turbo::Streams::TagBuilder.new(view).toast("Saved", close_button: false, duration: 2000)
    expect(markup).not_to include("UnmagicToast__dismiss", "close_button=")
    expect(markup).to include('data-duration="2000"', "Saved")
  end

  it "inherits duration and position when omitted" do
    node = toast_node
    expect(node["data-duration"]).to be_nil
    expect(node["data-position"]).to be_nil
  end

  it "renders all tones, with only bad interrupting" do
    Unmagic::Components::Toast::TONES.each do |tone|
      node = toast_node(tone: tone)
      expect(node["class"]).to include("UnmagicToast--#{tone}")
      expect(node["role"]).to eq(tone == :bad ? "alert" : nil)
    end
  end

  it "captures body and actions and retains the dismiss button" do
    node = toast_node do |toast|
      expect(toast.body { view.tag.strong("Custom body") }).to be_nil
      expect(toast.actions { view.tag.button("Dismiss", data: { unmagic_toast_dismiss: "" }) }).to be_nil
    end
    expect(node.at(".UnmagicToast__content strong").text).to eq("Custom body")
    expect(node.at(".UnmagicToast__message")).to be_nil
    expect(node.css("[data-unmagic-toast-dismiss]").size).to eq(2)
  end

  it "uses leading content instead of the default icon, unless an icon is explicit" do
    node = toast_node { |toast| toast.leading { view.tag.span("AM") } }
    expect(node.at(".UnmagicToast__leading").text).to eq("AM")
    expect(node.at(".UnmagicToast__icon")).to be_nil
    explicit = toast_node(icon: :x) { |toast| toast.leading { view.tag.span("AM") } }
    expect(explicit.at(".UnmagicToast__icon")).not_to be_nil
    expect(explicit.at(".UnmagicToast__leading")).to be_nil
    expect(toast_node(icon: false).at(".UnmagicToast__icon")).to be_nil
  end

  it "rejects invalid enumerations and numeric options" do
    [ { tone: :nope }, { position: :left }, { layout: :diagonal }, { width: :wide },
      { width: -1 }, { width: "100%;color:red" }, { duration: -1 }, { duration: Float::INFINITY },
      { duration: Float::NAN }, { duration: "0" }, { icon: :no_such_icon } ].each do |options|
      expect { toast_node(**options) }.to raise_error(ArgumentError)
    end
  end

  it "renders six uniquely named permanent regions, scoped within a panel" do
    doc = html(view.flash_toasts({}, id: "panel_toasts", scoped: true, position: :bottom, class: "custom"))
    mount = doc.at("unmagic-toasts")
    expect(mount.key?("scoped")).to be(true)
    expect(mount["position"]).to eq("bottom")
    expect(mount["class"]).to eq("custom")
    stacks = mount.css(".UnmagicToasts__stack")
    expect(stacks.size).to eq(6)
    expect(stacks.map { |node| node["id"] }.uniq.size).to eq(6)
    expect(stacks.map { |node| node["data-position"].to_sym }).to match_array(Unmagic::Components::Toast::POSITIONS)
    expect(stacks.map { |node| node["popover"] }).to all(be_nil)
    expect(html(view.flash_toasts({})).at("unmagic-toasts")["scoped"]).to be_nil
  end

  it "validates mount defaults" do
    expect { view.flash_toasts({}, duration: -1) }.to raise_error(ArgumentError)
    expect { view.flash_toasts({}, position: :nope) }.to raise_error(ArgumentError)
  end

  it "streams captured content to a named target" do
    markup = Turbo::Streams::TagBuilder.new(view).toast("Saved", target: "panel_toasts", duration: 0) do |toast|
      toast.actions { view.tag.button("Close", data: { unmagic_toast_dismiss: "" }) }
    end
    doc = html(markup)
    expect(doc.at("turbo-stream")["target"]).to eq("panel_toasts")
    expect(markup).to include('data-duration="0"', "UnmagicToast__actions")
  end
end

RSpec.describe "JavaScript toast blueprints" do
  let(:view) { build_view }

  it "renders inert prototypes separately from incoming notifications" do
    doc = html(view.flash_toasts({}))
    blueprint = doc.at("template[data-unmagic-toast-blueprint]")
    expect(blueprint).not_to be_nil
    expect(doc.css("template[data-unmagic-toast-template]")).to be_empty
    expect(doc.css("template[data-unmagic-toast-icon]").map { |node| node["data-unmagic-toast-icon"] }).to match_array(Unmagic::Components::Toast::TONES.map(&:to_s))
    # Parse the template contents explicitly for Nokogiri versions treating them as inert.
    content = html(blueprint.inner_html)
    expect(content.at(".UnmagicToast__title")).not_to be_nil
    expect(content.at(".UnmagicToast__actions button")["type"]).to eq("button")
    expect(content.at(".UnmagicToast__dismiss")["aria-label"]).to eq("Dismiss")
  end

  it "keeps logical identity separate from the root HTML id" do
    markup = Turbo::Streams::TagBuilder.new(view).toast("Saved", toast_id: "export-result", id: "export_toast")
    expect(markup).to include('data-toast-id="export-result"', 'id="export_toast"')
    expect { Unmagic::Components::Toast.new(view, "Saved", toast_id: " ") }.to raise_error(ArgumentError)
    expect { Unmagic::Components::Toast.new(view, "Saved", toast_id: 12) }.to raise_error(ArgumentError)
  end

  it "marks custom and absent icons so tone updates preserve them" do
    expect(html(Unmagic::Components::Toast.new(view, "Saved", icon: :x).render).at(".UnmagicToast")["data-toast-icon"]).to eq("custom")
    expect(html(Unmagic::Components::Toast.new(view, "Saved", icon: false).render).at(".UnmagicToast")["data-toast-icon"]).to eq("none")
  end
end
