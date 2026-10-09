# frozen_string_literal: true

RSpec.describe "video" do
  let(:view) { build_view }
  let(:chapters) { [ { start: 0, title: "Welcome" }, { start: "1:12", title: "Tools & <parts>" }, { start: 185, end: 240, title: "Questions" } ] }

  describe "#video_player" do
    it "renders the element with a native video the server draws" do
      player = html(view.video_player(id: "tour", src: "/tour.mp4", poster: "/still.jpg")).at("unmagic-video")

      expect(player["id"]).to eq("tour")
      expect(player["class"]).to eq("UnmagicVideo")
      expect([ player["provider"], player["src"], player["poster"] ]).to eq([ "native", "/tour.mp4", "/still.jpg" ])
      expect(player).to have_attribute("controls")

      video = player.at("> video")
      expect([ video["src"], video["poster"], video["preload"] ]).to eq([ "/tour.mp4", "/still.jpg", "metadata" ])
      expect(video).to have_attribute("playsinline")
      expect(video).to have_attribute("controls")
    end

    it "renders chapters as hidden data, escaped, with clocks read as seconds" do
      tags = html(view.video_player(id: "tour", src: "/tour.mp4", chapters: chapters)).css("unmagic-video-chapter")

      expect(tags.map { |tag| [ tag["start"], tag["end"], tag.text ] })
        .to eq([ [ "0", nil, "Welcome" ], [ "72", nil, "Tools & <parts>" ], [ "185", "240", "Questions" ] ])
      expect(tags).to all(have_attribute("hidden"))
    end

    it "reads chapters from any object answering start and title" do
      chapter = Struct.new(:start, :title).new("0:30", "Halfway")

      expect(html(view.video_player(id: "tour", chapters: [ chapter ])).at("unmagic-video-chapter")["start"]).to eq("30")
    end

    it "leaves a Stream iframe for the element to build, and takes the block" do
      player = html(view.video_player(id: "tour", src: "https://example.com/abc/iframe", provider: :stream, controls: false, title: "The tour") do
        view.video_cover("tour", image: "/still.jpg", label: "Play the tour")
      end).at("unmagic-video")

      expect(player["provider"]).to eq("stream")
      expect(player["title"]).to eq("The tour")
      expect(player).not_to have_attribute("controls")
      expect(player.at("video, iframe")).to be_nil
      expect(player.at("> unmagic-video-cover")).not_to be_nil
    end

    it "rejects an unknown provider and an unreadable time" do
      expect { view.video_player(id: "tour", provider: :vhs) }.to raise_error(ArgumentError, /unknown video_player provider :vhs/)
      expect { view.video_player(id: "tour", chapters: [ { start: "soon", title: "?" } ]) }.to raise_error(ArgumentError, /"soon"/)
    end
  end

  describe "#video_cover" do
    it "is a labelled button that plays its player" do
      cover = html(view.video_cover("tour", image: "/still.jpg", label: "Play the tour", caption: "The tour · 4:40", data: { x: 1 })).at("unmagic-video-cover")

      expect(cover["class"]).to eq("UnmagicVideoCover")
      expect(cover["data-x"]).to eq("1")
      button = cover.at("button.UnmagicVideoCover__button")
      expect([ button["type"], button["commandfor"], button["command"], button["aria-label"] ]).to eq([ "button", "tour", "--play", "Play the tour" ])
      expect(button.at("img.UnmagicVideoCover__image")["alt"]).to eq("")
      expect(button.at(".UnmagicVideoCover__caption").text).to eq("The tour · 4:40")
      expect(button.at(".UnmagicVideoCover__play svg")).not_to be_nil
    end
  end

  describe "#video_chapters" do
    it "lists seek buttons with timecodes" do
      list = html(view.video_chapters("tour", chapters + [ { start: 3672, title: "Late" } ])).at("ol.UnmagicVideoChapters")

      expect(list["aria-label"]).to eq("Chapters")
      buttons = list.css("button.UnmagicVideoChapters__chapter")
      expect(buttons.map { |button| [ button["commandfor"], button["command"], button["value"] ] }.uniq.first).to eq([ "tour", "--seek", "0" ])
      expect(buttons.map { |button| button.at(".UnmagicVideoChapters__time").text }).to eq([ "0:00", "1:12", "3:05", "1:01:12" ])
      expect(buttons[1].at(".UnmagicVideoChapters__title").text).to eq("Tools & <parts>")
      expect(buttons[1].text).to eq("1:12 Tools & <parts>")
    end

    it "renders nothing without chapters" do
      expect(view.video_chapters("tour", [])).to be_nil
    end
  end

  describe "#video_now_playing" do
    it "is an output for the player's chapter" do
      line = html(view.video_now_playing("tour")).at("p.UnmagicVideoNowPlaying")

      expect(line.at(".UnmagicVideoNowPlaying__label").text).to eq("Now playing:")
      output = line.at("output")
      expect([ output["for"], output["name"] ]).to eq([ "tour", "chapter" ])
    end
  end

  describe Unmagic::Components::Video do
    it "reads and writes a player's clock" do
      expect([ "72", "1:12", "1:01:12", 7.5 ].map { |value| described_class.seconds(value) }).to eq([ 72, 72, 3672, 7.5 ])
      expect([ 0, 72, 3672 ].map { |seconds| described_class.timecode(seconds) }).to eq([ "0:00", "1:12", "1:01:12" ])
    end
  end
end
