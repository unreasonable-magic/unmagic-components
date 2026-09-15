# frozen_string_literal: true

module Unmagic
  module Components
    # The class string for a button, so the look composes with link_to, button_to
    # and form.submit alike. See ActionViewHelpers#button_classes.
    #
    # The components call this directly rather than through the view helper: a
    # host with a button_classes helper of its own shadows the gem's, and its
    # signature is nobody's business here.
    module Button
      VARIANTS = %i[default primary ghost danger icon].freeze
      SIZES = %i[small large].freeze

      def self.classes(variant = :default, size: nil)
        unless VARIANTS.include?(variant)
          raise ArgumentError, "unknown button variant #{variant.inspect} (expected one of #{VARIANTS.inspect})"
        end
        unless size.nil? || SIZES.include?(size)
          raise ArgumentError, "unknown button size #{size.inspect} (expected one of #{SIZES.inspect})"
        end

        [ "UnmagicButton", ("UnmagicButton--#{variant}" unless variant == :default), ("UnmagicButton--#{size}" if size) ]
          .compact.join(" ")
      end
    end
  end
end
