# frozen_string_literal: true

require "unmagic_icon"

module Unmagic
  module Components
    # The glyphs the components draw for themselves — a close button, a toast's
    # tone, a tool call's state. Rendered inline through unmagic-icon from a subset
    # of Lucide the gem ships in app/assets/icons/lucide (ISC, see the LICENSE
    # beside the files), so a host needs no icon set of its own: kp2 downloads
    # Phosphor, not Lucide, and the components still draw.
    #
    # The library is read from the gem's own directory rather than looked up in
    # unmagic-icon's registry, which only learns about engine icons when the host
    # leaves unmagic-icon to initialise itself. Under Rails the same files are also
    # registered as "unmagic_components:lucide", for a host that wants to draw them.
    module Icons
      DIRECTORY = File.expand_path("../../../app/assets/icons/lucide", __dir__)

      # The glyph a tone leads with, where it has one.
      TONE_ICONS = { good: :circle_check, warn: :triangle_alert, bad: :circle_x, info: :info }.freeze

      class << self
        # An icon by its Lucide name as a symbol, :circle_check for circle-check.
        # Decorative unless the caller says otherwise, so aria-hidden is on by default.
        def svg(view, name, **options)
          library.find(name.to_s.tr("_", "-")).render(
            "aria-hidden": "true", **options, class: view.class_names("UnmagicIcon", options[:class])
          )
        rescue Unmagic::Icon::IconNotFoundError
          raise ArgumentError, "unknown icon #{name.inspect}"
        end

        def names
          Dir[File.join(DIRECTORY, "*.svg")].map { |path| File.basename(path, ".svg").tr("-", "_").to_sym }.sort
        end

        private

        # The library's manifest-free lookup falls back to nothing, so an unknown
        # name raises rather than drawing some other glyph.
        def library
          @library ||= Unmagic::Icon::Library.new(name: "unmagic_components:lucide", path: DIRECTORY)
        end
      end
    end
  end
end
