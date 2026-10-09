# frozen_string_literal: true

require "active_support/core_ext/string/filters"
require "unmagic/color"

module Unmagic
  module Components
    class Avatar
      # What sits behind an avatar's initials, as a fill's #call hands it back for
      # a seed. Any part can be nil:
      #
      # - class_name: a CSS class on the avatar that colours it (Tints' classes)
      # - background: any CSS background (a colour, a gradient), written to the
      #   avatar's --unmagic-avatar-background
      # - foreground: the initials' CSS colour, written to --unmagic-avatar-foreground
      Fill = Data.define(:class_name, :background, :foreground) do
        def initialize(class_name: nil, background: nil, foreground: nil)
          super
        end

        def style
          [
            ("--unmagic-avatar-background: #{background};" if background),
            ("--unmagic-avatar-foreground: #{foreground};" if foreground)
          ].compact.join(" ").presence
        end
      end

      # The seams below each take a seed (by default the avatar's name) and are
      # deterministic: the same seed gets the same fill on every page and every
      # server. Ruby's String#hash is seeded per process, so it can't be used;
      # unmagic-color's string hash is stable.
      def self.seed_hash(seed)
        Unmagic::Color::String::HashFunction.call(seed.to_s.squish.downcase)
      end

      # Six palette tints, as UnmagicAvatar--tint-1 … -6. The default: soft,
      # light-and-dark-aware, and recoloured from CSS.
      class Tints
        COUNT = 6

        def call(seed)
          Fill.new(class_name: "UnmagicAvatar--tint-#{(Avatar.seed_hash(seed) % COUNT) + 1}")
        end
      end

      # One colour picked from the whole hue wheel, with white initials on it, so
      # keep it dark and saturated enough to stay legible. lightness: is a
      # percentage; saturation: a range the seed picks from.
      class Solid
        def initialize(lightness: 45, saturation: 45..70, foreground: "#ffffff")
          @lightness = lightness
          @saturation = saturation
          @foreground = foreground
        end

        def call(seed)
          Fill.new(background: color(seed).to_hex, foreground: @foreground)
        end

        # The seed's colour, for a host that wants it outside an avatar.
        def color(seed)
          Unmagic::Color::HSL.derive(Avatar.seed_hash(seed), lightness: @lightness, saturation_range: @saturation)
        end
      end

      # Solid's colour eased into a second stop: the hue turned by hue_shift:
      # degrees and lightened by lighten: (0–1), at angle: degrees. Keep the shift
      # gentle so both stops stay in one family.
      class Gradient < Solid
        def initialize(angle: 135, hue_shift: 25, lighten: 0.15, **solid)
          super(**solid)
          @angle = angle
          @hue_shift = hue_shift
          @lighten = lighten
        end

        def call(seed)
          base = color(seed)
          accent = Unmagic::Color::HSL.new(
            hue: (base.hue.value + @hue_shift) % 360,
            saturation: base.saturation.value,
            lightness: base.lightness.value
          ).lighten(@lighten)

          Fill.new(background: "linear-gradient(#{@angle}deg, #{accent.to_hex} 0%, #{base.to_hex} 100%)",
            foreground: @foreground)
        end
      end
    end
  end
end
