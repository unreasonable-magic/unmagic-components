# frozen_string_literal: true

require "active_support/core_ext/string/filters"

module Unmagic
  module Components
    # A person's or organisation's picture, falling back to their initials. See
    # ActionViewHelpers#avatar.
    class Avatar
      SIZES = %i[small medium large xlarge xxlarge].freeze
      SHAPES = %i[circle square].freeze
      FITS = %i[cover contain].freeze

      # How a plain string is read for its initials. A name object that answers
      # #initials itself is used as it is.
      KINDS = { name: Name, person: Name::Person, organization: Name::Organization }.freeze

      # Each named size's box, which a loading avatar's skeleton matches.
      DIMENSIONS = { small: "1.5rem", medium: "2rem", large: "2.5rem", xlarge: "3.5rem", xxlarge: "5rem" }.freeze

      # A size given as a CSS length rather than by name, for a box between the
      # named ones.
      LENGTH = /\A\d+(\.\d+)?(rem|em|px)\z/

      class << self
        # "Ada Lovelace" → "AL", "Plato" → "P". kind: reads it as a :person or an
        # :organization instead.
        def initials(name, kind: :name)
          name_object(name, kind).initials
        end

        # The fill an avatar seeded with seed: wears, through the configured
        # avatar_fill unless fill: is given. For a host drawing the same colours
        # somewhere an avatar can't go, such as an email or a JSON payload. nil for
        # a blank seed or fill: false.
        def fill_for(seed, fill: nil)
          fill = Components.configuration.avatar_fill if fill.nil?
          return if fill == false || seed.to_s.squish.empty?

          fill.call(seed)
        end

        def name_object(name, kind)
          return name if name.respond_to?(:initials)

          KINDS.fetch(kind) do
            raise ArgumentError, "unknown avatar kind #{kind.inspect} (expected one of #{KINDS.keys.inspect})"
          end.new(name)
        end

        def dimension(size)
          DIMENSIONS.fetch(size, size)
        end

        def validate!(size, shape, fit: :cover)
          unless SIZES.include?(size) || (size.is_a?(String) && size.match?(LENGTH))
            raise ArgumentError, "unknown avatar size #{size.inspect} (expected one of #{SIZES.inspect}, or a CSS length)"
          end
          unless SHAPES.include?(shape)
            raise ArgumentError, "unknown avatar shape #{shape.inspect} (expected one of #{SHAPES.inspect})"
          end
          return if FITS.include?(fit)

          raise ArgumentError, "unknown avatar fit #{fit.inspect} (expected one of #{FITS.inspect})"
        end

        # The class and knob a size puts on an element named block.
        def size_attributes(block, size)
          if size.is_a?(String)
            [ "#{block}--sized", "--unmagic-avatar-size: #{size};" ]
          else
            [ "#{block}--#{size}", nil ]
          end
        end
      end

      def initialize(view, name, src: nil, size: :medium, shape: :circle, fit: :cover, kind: :name, initials: nil,
        seed: nil, fill: nil, skeleton: false, **options)
        self.class.validate!(size, shape, fit: fit)

        @view = view
        @name_object = self.class.name_object(name, kind)
        @name = name.to_s.squish
        @src = src
        @size = size
        @shape = shape
        @fit = fit
        @initials = initials
        @seed = seed.nil? ? @name : seed
        @fill = fill
        @skeleton = skeleton
        @options = options
      end

      # The initials always render and the image sits on top of them, so an image
      # that fails to load shows the initials through it without any script.
      def render
        return Skeleton.new(view).circle(size: self.class.dimension(@size), **@options) if @skeleton

        fill = self.class.fill_for(@seed, fill: @fill) if @name.present?
        size_class, size_style = self.class.size_attributes("UnmagicAvatar", @size)

        view.content_tag(:span, **@options,
          role: "img",
          "aria-label": @name.presence,
          title: @name.presence,
          style: [ size_style, fill&.style, @options[:style] ].compact.join(" ").presence,
          class: view.class_names("UnmagicAvatar", size_class,
            { "UnmagicAvatar--square" => @shape == :square, "UnmagicAvatar--contain" => @fit == :contain },
            fill&.class_name, @options[:class])) do
          safe_join [ *initials_tags, image_tag ].compact
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      # Where the name has a longer mark, both render and the avatar's own width
      # picks one (a container query), so the same call reads right at any size.
      def initials_tags
        short, long = initials

        if long == short
          [ initials_tag(short) ]
        else
          [ initials_tag(long, "UnmagicAvatar__initials--long"), initials_tag(short, "UnmagicAvatar__initials--short") ]
        end
      end

      # The image carries the initials too: a sized image that fails to load draws
      # the browser's broken-image glyph over the initials under it, so the CSS
      # covers it with the fill and these (a broken image renders ::before; a
      # loaded one doesn't).
      def image_tag
        return if @src.blank?

        short, long = initials
        tag.img(src: @src, alt: "", loading: "lazy", decoding: "async", class: "UnmagicAvatar__image",
          data: { initials: short, initials_long: (long unless long == short) })
      end

      def initials
        @initials_pair ||=
          if @name.empty?
            [ "—", "—" ]
          else
            short = @initials || @name_object.initials
            [ short, @initials || (@name_object.respond_to?(:initials_long) ? @name_object.initials_long : short) ]
          end
      end

      def initials_tag(text, modifier = nil)
        tag.span(text, class: view.class_names("UnmagicAvatar__initials", modifier), "aria-hidden": "true")
      end
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
        size_class, size_style = Avatar.size_attributes("UnmagicAvatarGroup", @size)

        view.content_tag(:div, **@options, role: "group", "aria-label": label,
          style: [ size_style, @options[:style] ].compact.join(" ").presence,
          class: view.class_names("UnmagicAvatarGroup", size_class, @options[:class])) do
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
