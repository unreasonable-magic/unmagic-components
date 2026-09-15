# frozen_string_literal: true

RSpec.describe "local times and tooltips" do
  let(:view) { build_view }
  let(:time) { Time.utc(2026, 9, 16, 4, 33, 24) }

  describe "#local_time_tag" do
    it "renders the element around a <time>, with the server's own rendering as the fallback" do
      element = html(view.local_time_tag(time)).at("unmagic-time")

      expect(element["datetime"]).to eq("2026-09-16T04:33:24Z")
      expect(element["format"]).to eq("medium")
      expect(element["compact"]).to be_nil

      inner = element.at("> time")
      expect(inner["datetime"]).to eq("2026-09-16T04:33:24Z")
      expect(inner["title"]).to be_nil
      expect(inner.text).to eq(I18n.l(time.in_time_zone, format: :default))
    end

    it "falls back through I18n for each absolute format" do
      text = ->(format) { html(view.local_time_tag(time, format: format)).at("time").text }

      expect(text.call(:short)).to eq(I18n.l(time.in_time_zone, format: :short))
      expect(text.call(:long)).to eq(I18n.l(time.in_time_zone, format: :long))
      expect(text.call(:date)).to eq(I18n.l(time.to_date, format: :long))
      expect(text.call(:time)).to eq("04:33")
    end

    it "keeps the datetime in UTC but renders the fallback in Time.zone" do
      element = Time.use_zone("Australia/Perth") { html(view.local_time_tag(time)).at("unmagic-time") }

      expect(element["datetime"]).to eq("2026-09-16T04:33:24Z")
      expect(element.at("time").text).to include("12:33:24 +0800")
    end

    it "phrases a relative time as a distance, with the full time in its title" do
      past = html(view.local_time_tag(2.hours.ago, format: :relative, compact: true)).at("unmagic-time")
      future = html(view.local_time_tag(3.days.from_now, format: :relative)).at("unmagic-time")

      expect(past["format"]).to eq("relative")
      # Rails renders compact as an HTML boolean attribute; the element only asks
      # whether it is there.
      expect(past.key?("compact")).to be(true)
      expect(past.at("time").text).to eq("about 2 hours ago")
      expect(past.at("time")["title"]).to be_present
      expect(future.at("time").text).to eq("in 3 days")
    end

    it "renders an em dash for a blank time" do
      expect(view.local_time_tag(nil)).to eq("—")
    end

    it "passes other options to the element and rejects an unknown format" do
      expect(html(view.local_time_tag(time, class: "muted")).at("unmagic-time")["class"]).to eq("muted")
      expect { view.local_time_tag(time, format: :epoch) }.to raise_error(ArgumentError, /unknown local_time_tag format :epoch/)
    end
  end

  describe "#tooltip" do
    it "styles plain text content as a term" do
      element = html(view.tooltip("canonical", text: "The original URL.")).at("unmagic-tooltip")

      expect(element.text).to eq("canonical")
      expect(element["text"]).to eq("The original URL.")
      expect(element["placement"]).to eq("top")
      expect(element["class"]).to eq("UnmagicTooltip UnmagicTooltip--term")
    end

    it "leaves block content as it is, unless asked" do
      plain = html(view.tooltip(text: "Copy") { view.tag.button("Copy") }).at("unmagic-tooltip")
      term = html(view.tooltip(text: "Why", term: true) { "Why?" }).at("unmagic-tooltip")

      expect(plain["class"]).to eq("UnmagicTooltip")
      expect(plain.at("> button").text).to eq("Copy")
      expect(term["class"]).to include("UnmagicTooltip--term")
    end

    it "takes a placement and extra classes, and rejects an unknown placement" do
      element = html(view.tooltip("x", text: "y", placement: :bottom, class: "ml-1")).at("unmagic-tooltip")

      expect(element["placement"]).to eq("bottom")
      expect(element["class"]).to eq("UnmagicTooltip UnmagicTooltip--term ml-1")
      expect { view.tooltip("x", text: "y", placement: :left) }.to raise_error(ArgumentError, /unknown tooltip placement :left/)
    end
  end
end
