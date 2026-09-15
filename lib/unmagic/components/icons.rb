# frozen_string_literal: true

module Unmagic
  module Components
    # The handful of glyphs the components draw for themselves — a close button, a
    # toast's tone, a copy button's confirmation. Inline SVG so the gem depends on no
    # icon library and no host helper. Paths are from Lucide (ISC licence).
    module Icons
      PATHS = {
        x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
        check: '<path d="M20 6 9 17l-5-5"/>',
        circle_check: '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
        circle_x: '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>',
        triangle_alert: '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/>' \
          '<path d="M12 9v4"/><path d="M12 17h.01"/>',
        info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
        copy: '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/>' \
          '<path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
        rotate: '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
        ellipsis_vertical: '<circle cx="12" cy="12" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="12" cy="19" r="1"/>',
        arrow_left: '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
        chevron_down: '<path d="m6 9 6 6 6-6"/>'
      }.freeze

      # The glyph a tone leads with, where it has one.
      TONE_ICONS = { good: :circle_check, warn: :triangle_alert, bad: :circle_x, info: :info }.freeze

      def self.svg(view, name, **options)
        paths = PATHS.fetch(name) { raise ArgumentError, "unknown icon #{name.inspect}" }

        view.tag.svg(
          paths.html_safe, # rubocop:disable Rails/OutputSafety -- the constant markup above, never input
          xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
          "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true",
          **options, class: view.class_names("UnmagicIcon", options[:class])
        )
      end
    end
  end
end
