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
