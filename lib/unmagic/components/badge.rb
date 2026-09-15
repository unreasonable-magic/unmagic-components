# frozen_string_literal: true

module Unmagic
  module Components
    # The class string for a badge. See ActionViewHelpers#badge.
    #
    # The look lives in CSS rather than in the helper so markup that can only carry
    # a class name — a tooltip trigger, generated HTML — can wear it too.
    module Badge
      TONES = %i[neutral good warn bad info accent].freeze

      def self.classes(tone = :neutral)
        unless TONES.include?(tone)
          raise ArgumentError, "unknown badge tone #{tone.inspect} (expected one of #{TONES.inspect})"
        end

        tone == :neutral ? "UnmagicBadge" : "UnmagicBadge UnmagicBadge--#{tone}"
      end
    end
  end
end
