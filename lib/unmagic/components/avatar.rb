# frozen_string_literal: true

require "active_support/core_ext/string/filters"
require "unmagic/color"

module Unmagic
  module Components
    # A person's or organisation's picture, falling back to their initials. See
    # ActionViewHelpers#avatar.
    class Avatar
      SIZES = %i[small medium large].freeze
      SHAPES = %i[circle square].freeze
      TINTS = 6

      # The skeleton for each size, so a loading avatar and a loaded one line up.
      DIMENSIONS = { small: "1.5rem", medium: "2rem", large: "2.5rem" }.freeze

      class << self
        # "Ada Lovelace" → "AL", "Plato" → "P".
        def initials(name)
          words = name.to_s.squish.split
          return "" if words.empty?

          [ words.first, (words.last if words.size > 1) ].compact.map { |word| word[0] }.join.upcase
        end

        # One of six palette tints, the same for a name on every page and every
        # server. Ruby's String#hash is seeded per process, so it can't be used here;
        # unmagic-color's string hash is stable.
        def tint(name)
          normalised = name.to_s.squish.downcase
          return if normalised.empty?

          (Unmagic::Color::String::HashFunction.call(normalised) % TINTS) + 1
        end

        def validate!(size, shape)
          unless SIZES.include?(size)
            raise ArgumentError, "unknown avatar size #{size.inspect} (expected one of #{SIZES.inspect})"
          end
          return if SHAPES.include?(shape)

          raise ArgumentError, "unknown avatar shape #{shape.inspect} (expected one of #{SHAPES.inspect})"
        end
      end

      def initialize(view, name, src: nil, size: :medium, shape: :circle, tint: true, skeleton: false, **options)
        self.class.validate!(size, shape)

        @view = view
        @name = name.to_s.squish
        @src = src
        @size = size
        @shape = shape
        @tint = tint
        @skeleton = skeleton
        @options = options
      end

      # The initials always render and the image sits on top of them, so an image
      # that fails to load shows the initials through it without any script.
      def render
        return Skeleton.new(view).circle(size: DIMENSIONS.fetch(@size), **@options) if @skeleton

        tint = self.class.tint(@name) if @tint
        view.content_tag(:span, **@options,
          role: "img",
          "aria-label": @name.presence,
          title: @name.presence,
          class: view.class_names("UnmagicAvatar", "UnmagicAvatar--#{@size}",
            { "UnmagicAvatar--square" => @shape == :square, "UnmagicAvatar--tint-#{tint}" => tint }, @options[:class])) do
          safe_join [
            tag.span(@name.present? ? self.class.initials(@name) : "—", class: "UnmagicAvatar__initials", "aria-hidden": "true"),
            (tag.img(src: @src, alt: "", loading: "lazy", decoding: "async", class: "UnmagicAvatar__image") if @src.present?)
          ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end

    # A stack of avatars, collapsing past max: into a "+N" counter. See
    # ActionViewHelpers#avatar_group.
    class AvatarGroup
      def initialize(view, max: nil, size: :medium, shape: :circle, **options)
        Avatar.validate!(size, shape)

        @view = view
        @max = max
        @size = size
        @shape = shape
        @options = options
        @people = []
      end

      # The group sets the size, so a stack never mixes them.
      def avatar(name, **options)
        raise ArgumentError, "an avatar in a group takes the group's size" if options.key?(:size)
        raise ArgumentError, "an avatar in a group takes the group's shape" if options.key?(:shape)

        @people << [ name, options ]
        nil
      end

      def render
        shown = @max ? @people.first(@max) : @people
        hidden = @people.drop(shown.size)
        label = I18n.t("unmagic.components.avatar.group", count: @people.size, default: "%{count} people")

        view.content_tag(:div, **@options, role: "group", "aria-label": label,
          class: view.class_names("UnmagicAvatarGroup", "UnmagicAvatarGroup--#{@size}", @options[:class])) do
          view.safe_join [
            *shown.map { |name, options| Avatar.new(view, name, size: @size, shape: @shape, **options).render },
            (more(hidden) if hidden.any?)
          ].compact
        end
      end

      private

      attr_reader :view

      def more(hidden)
        view.tag.span(I18n.t("unmagic.components.avatar.more", count: hidden.size, default: "+%{count}"),
          title: hidden.map(&:first).join(", "),
          class: view.class_names("UnmagicAvatarGroup__more", { "UnmagicAvatar--square" => @shape == :square }))
      end
    end
  end
end
