# frozen_string_literal: true

module Unmagic
  module Components
    # A video the page drives with its own controls. See
    # ActionViewHelpers#video_player and app/assets/javascripts/unmagic/components/video.js.
    class Video
      PROVIDERS = %i[native stream].freeze

      # A labelled point in a video. start and end are seconds.
      Chapter = Data.define(:start, :end, :title) do
        # A Hash or any object answering start and title (and optionally end),
        # with times as seconds or a clock ("1:12").
        def self.from(chapter)
          read = ->(key) { chapter.is_a?(Hash) ? (chapter[key] || chapter[key.to_s]) : chapter.try(key) }
          stop = read.call(:end)
          new(start: Video.seconds(read.call(:start)), end: (Video.seconds(stop) unless stop.nil?), title: read.call(:title).to_s)
        end
      end

      class << self
        # "1:12" → 72, "1:01:12" → 3672, 72 → 72.
        def seconds(value)
          return value if value.is_a?(Numeric)

          parts = value.to_s.strip.split(":")
          raise ArgumentError, "can't read #{value.inspect} as a time in a video" if parts.empty? || parts.any? { |part| part !~ /\A\d+(\.\d+)?\z/ }

          parts.reduce(0) { |total, part| (total * 60) + (part.include?(".") ? part.to_f : part.to_i) }
        end

        # 72 → "1:12", widening to "1:01:12" past the hour, as the element writes it.
        def timecode(seconds)
          whole = seconds.to_i
          hours, rest = whole.divmod(3600)
          minutes, secs = rest.divmod(60)
          hours.positive? ? format("%d:%02d:%02d", hours, minutes, secs) : format("%d:%02d", minutes, secs)
        end

        def chapters(chapters)
          Array(chapters).map { |chapter| chapter.is_a?(Chapter) ? chapter : Chapter.from(chapter) }
        end
      end

      def initialize(view, id:, src: nil, provider: :native, chapters: [], poster: nil, controls: true, **options)
        unless PROVIDERS.include?(provider)
          raise ArgumentError, "unknown video_player provider #{provider.inspect} (expected one of #{PROVIDERS.inspect})"
        end

        @view = view
        @id = id
        @src = src
        @provider = provider
        @chapters = self.class.chapters(chapters)
        @poster = poster
        @controls = controls
        @options = options
      end

      # A native video renders its <video> on the server, so it plays before the
      # script loads; a Stream iframe is built by the element on first play.
      def render(content = nil)
        view.content_tag("unmagic-video", **@options,
          id: @id,
          provider: @provider,
          src: @src,
          poster: @poster,
          controls: (true if @controls),
          class: view.class_names("UnmagicVideo", @options[:class])) do
          view.safe_join [ native_video, *chapter_tags, content ].compact
        end
      end

      private

      attr_reader :view

      def native_video
        return unless @provider == :native && @src.present?

        view.tag.video(src: @src, poster: @poster, controls: @controls, preload: "metadata", playsinline: true)
      end

      def chapter_tags
        @chapters.map do |chapter|
          view.content_tag("unmagic-video-chapter", chapter.title, start: chapter.start, end: chapter.end, hidden: true)
        end
      end
    end

    # What covers a video until it plays: a button with the still, a play glyph
    # and a caption. See ActionViewHelpers#video_cover.
    class VideoCover
      def initialize(view, player_id, image:, label:, caption: nil, **options)
        @view = view
        @player_id = player_id
        @image = image
        @label = label
        @caption = caption
        @options = options
      end

      def render
        view.content_tag("unmagic-video-cover", **@options, class: view.class_names("UnmagicVideoCover", @options[:class])) do
          view.tag.button(type: "button", commandfor: @player_id, command: "--play", "aria-label": @label, title: @label,
            class: "UnmagicVideoCover__button") do
            view.safe_join [
              (view.tag.img(src: @image, alt: "", class: "UnmagicVideoCover__image") if @image.present?),
              (view.tag.span(@caption, class: "UnmagicVideoCover__caption") if @caption.present?),
              view.tag.span(Icons.svg(view, :play), class: "UnmagicVideoCover__play")
            ].compact
          end
        end
      end

      private

      attr_reader :view
    end

    # A video's chapters as buttons that seek it, marking the one playing. See
    # ActionViewHelpers#video_chapters.
    class VideoChapters
      def initialize(view, player_id, chapters, **options)
        @view = view
        @player_id = player_id
        @chapters = Video.chapters(chapters)
        @options = options
      end

      def render
        return if @chapters.empty?

        label = I18n.t("unmagic.components.video.chapters", default: "Chapters")
        view.tag.ol(**@options, "aria-label": label, class: view.class_names("UnmagicVideoChapters", @options[:class])) do
          view.safe_join(@chapters.map { |chapter| item(chapter) })
        end
      end

      private

      attr_reader :view

      def item(chapter)
        view.tag.li do
          view.tag.button(type: "button", commandfor: @player_id, command: "--seek", value: chapter.start,
            class: "UnmagicVideoChapters__chapter") do
            # The space keeps the button's name "1:12 The workshop", not "1:12The workshop".
            view.safe_join [
              view.tag.span(Video.timecode(chapter.start), class: "UnmagicVideoChapters__time"),
              view.tag.span(chapter.title, class: "UnmagicVideoChapters__title")
            ], " "
          end
        end
      end
    end
  end
end
