# frozen_string_literal: true

RSpec.describe "timeline" do
  let(:view) { build_view }

  def timeline(**options, &block)
    html(view.timeline(**options, &block))
  end

  it "renders an ordered list of events, in the order given" do
    list = timeline(label: "Order history") do |t|
      t.event "Order placed"
      t.event "Shipped"
      t.event "Delivered"
    end.at("ol")

    expect(list["class"]).to eq("UnmagicTimeline UnmagicTimeline--vertical")
    expect(list["aria-label"]).to eq("Order history")
    expect(list.css("> li.UnmagicTimeline__event .UnmagicTimeline__title").map(&:text)).to eq([ "Order placed", "Shipped", "Delivered" ])
  end

  it "lays out horizontally" do
    expect(timeline(orientation: :horizontal) { |t| t.event "v1.0" }.at("ol")["class"])
      .to eq("UnmagicTimeline UnmagicTimeline--horizontal")
  end

  describe "markers" do
    it "draws a dot by default, hidden from assistive technology" do
      marker = timeline { |t| t.event "Created" }.at(".UnmagicTimeline__marker")

      expect(marker["class"]).to eq("UnmagicTimeline__marker UnmagicTimeline__marker--dot")
      expect(marker["aria-hidden"]).to eq("true")
      expect(marker.children).to be_empty
    end

    it "draws an icon" do
      marker = timeline { |t| t.event "Deployed", icon: :rocket }.at(".UnmagicTimeline__marker")

      expect(marker["class"]).to include("UnmagicTimeline__marker--icon")
      expect(marker.at("svg")["data-unmagic-icon"]).to eq("unmagic_components:lucide/rocket")
    end

    it "draws a small avatar from a name or from avatar options" do
      markers = timeline do |t|
        t.event "Ada commented", avatar: "Ada Lovelace"
        t.event "Grace commented", avatar: { name: "Grace Hopper", src: "/grace.png" }
      end.css(".UnmagicTimeline__marker--avatar")

      expect(markers[0].at(".UnmagicAvatar.UnmagicAvatar--small").text).to eq("AL")
      expect(markers[1].at(".UnmagicAvatar--small img")["src"]).to eq("/grace.png")
      expect(markers.map { |marker| marker["aria-hidden"] }).to eq(%w[true true])
    end
  end

  it "counts in the marker: style, leaving icons and avatars alone" do
    markers = timeline(marker: :decimal) do |t|
      t.event "Intro call"
      t.event "Technical chat", icon: :code
      t.event "Meet the founders", avatar: "Ada Lovelace"
      t.event "Offer"
    end.css(".UnmagicTimeline__marker")

    expect(markers.map { |marker| marker["class"].split.last }).to eq(%w[
      UnmagicTimeline__marker--counter UnmagicTimeline__marker--icon UnmagicTimeline__marker--avatar UnmagicTimeline__marker--counter
    ])
    expect([ markers[0].text, markers[3].text ]).to eq(%w[1 4])
    expect(markers[0]["aria-hidden"]).to eq("true")
  end

  it "counts the way CSS's list-style-type names do" do
    counters = lambda do |marker, count|
      timeline(marker: marker) { |t| count.times { |index| t.event "Step #{index}" } }.css(".UnmagicTimeline__marker").map(&:text)
    end

    expect(counters.(:lower_alpha, 28).values_at(0, 1, 25, 26, 27)).to eq(%w[a b z aa ab])
    expect(counters.(:upper_alpha, 3)).to eq(%w[A B C])
    expect(counters.(:lower_roman, 14).values_at(0, 3, 8, 13)).to eq(%w[i iv ix xiv])
    expect(counters.(:upper_roman, 4)).to eq(%w[I II III IV])
    expect(counters.(:dot, 2)).to eq([ "", "" ])
  end

  describe "time" do
    around { |example| Time.use_zone("UTC") { example.run } }

    it "draws a moment through local_time_tag" do
      time = timeline { |t| t.event "Paid", time: Time.utc(2026, 9, 22, 16, 33) }.at("unmagic-time.UnmagicTimeline__time")

      expect(time["format"]).to eq("medium")
      expect(time.at("time")["datetime"]).to eq("2026-09-22T16:33:00Z")
    end

    it "passes time_format: through, and reads a Date as a date" do
      page = timeline do |t|
        t.event "Commented", time: 3.hours.ago, time_format: :relative
        t.event "Released", time: Date.new(2026, 9, 1)
      end

      expect(page.css("unmagic-time").map { |time| time["format"] }).to eq(%w[relative date])
    end

    it "prints markup as it is" do
      expect(timeline { |t| t.event "Intro call", time: view.badge("30 mins") }.at(".UnmagicTimeline__time .UnmagicBadge").text)
        .to eq("30 mins")
    end

    it "prints a string as it is, and nothing for nil" do
      page = timeline do |t|
        t.event "Launch", time: "Q4"
        t.event "Kickoff"
      end

      expect(page.at("span.UnmagicTimeline__time").text).to eq("Q4")
      expect(page.css(".UnmagicTimeline__time").size).to eq(1)
    end
  end

  it "sets the tone, and marks pending events for eyes and ears" do
    events = timeline do |t|
      t.event "Build failed", tone: :bad
      t.event "Ships", pending: true
    end.css("li")

    expect(events.map { |event| event["data-tone"] }).to eq(%w[bad neutral])
    expect(events[0]["data-pending"]).to be_nil
    expect(events[1].key?("data-pending")).to be(true)
    expect(events[1].at(".UnmagicTimeline__header .UnmagicVisuallyHidden").text).to eq("(upcoming)")
    expect(events[0].at(".UnmagicVisuallyHidden")).to be_nil
  end

  it "links the title with href:, and renders a description and a body only when given" do
    events = timeline do |t|
      t.event "Deployed", href: "/deploys/42", description: "a1b2c3d" do
        "<pre>log</pre>".html_safe
      end
      t.event "Queued"
    end.css("li")

    expect(events[0].at("a.UnmagicTimeline__title")["href"]).to eq("/deploys/42")
    expect(events[0].at("p.UnmagicTimeline__description").text).to eq("a1b2c3d")
    expect(events[0].at("div.UnmagicTimeline__body > pre").text).to eq("log")
    expect(events[1].at("span.UnmagicTimeline__title")).not_to be_nil
    expect(events[1].at(".UnmagicTimeline__description, .UnmagicTimeline__body")).to be_nil
  end

  it "passes other options to the list and to each event" do
    list = timeline(id: "history", class: "mt-4", data: { turbo_permanent: true }) do |t|
      t.event "Created", id: "event_1", class: "opacity-50", data: { kind: "create" }
    end.at("ol")

    expect(list["id"]).to eq("history")
    expect(list["class"]).to eq("UnmagicTimeline UnmagicTimeline--vertical mt-4")
    expect(list["data-turbo-permanent"]).to eq("true")
    event = list.at("li")
    expect([ event["id"], event["class"], event["data-kind"] ]).to eq([ "event_1", "UnmagicTimeline__event opacity-50", "create" ])
  end

  it "renders nothing without events" do
    expect(view.timeline { nil }).to be_nil
    expect(view.timeline).to be_nil
  end

  it "renders placeholder events as a skeleton" do
    group = timeline(skeleton: true).at(".UnmagicSkeletonGroup")

    expect(group["role"]).to eq("status")
    expect(group.css("ol.UnmagicTimeline > li.UnmagicTimeline__event").size).to eq(3)
    expect(group.css(".UnmagicSkeleton").size).to be >= 3
  end

  it "raises on unknown options and impossible events" do
    expect { view.timeline(marker: :disc) }.to raise_error(ArgumentError, /unknown timeline marker :disc/)
    expect { view.timeline(orientation: :diagonal) }.to raise_error(ArgumentError, /unknown timeline orientation :diagonal/)
    expect { view.timeline { |t| t.event "x", tone: :great } }.to raise_error(ArgumentError, /unknown timeline tone :great/)
    expect { view.timeline { |t| t.event "" } }.to raise_error(ArgumentError, /needs a title/)
    expect { view.timeline { |t| t.event "x", icon: :rocket, avatar: "Ada" } }.to raise_error(ArgumentError, /icon: or avatar:/)
    expect { view.timeline { |t| t.event "x", icon: :no_such_glyph } }.to raise_error(ArgumentError, /unknown icon/)
  end
end
