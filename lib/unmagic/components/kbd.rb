# frozen_string_literal: true

module Unmagic
  module Components
    # A key or a combination of keys, drawn as key caps. See ActionViewHelpers#kbd.
    class Kbd
      # Named keys: the glyph shown, and the name a screen reader gets instead,
      # since it pronounces "⌘" however it likes.
      KEYS = {
        cmd: [ "⌘", "cmd" ], ctrl: [ "Ctrl", "ctrl" ], alt: [ "⌥", "alt" ], shift: [ "⇧", "shift" ],
        enter: [ "↵", "enter" ], esc: [ "Esc", "esc" ], tab: [ "Tab", "tab" ], space: [ "Space", "space" ],
        up: [ "↑", "up" ], down: [ "↓", "down" ], left: [ "←", "left" ], right: [ "→", "right" ],
        backspace: [ "⌫", "backspace" ], delete: [ "⌦", "delete" ]
      }.freeze

      NAMES = {
        cmd: "Command", ctrl: "Control", alt: "Option", shift: "Shift", enter: "Enter", esc: "Escape", tab: "Tab",
        space: "Space", up: "Up", down: "Down", left: "Left", right: "Right", backspace: "Backspace", delete: "Delete"
      }.freeze

      def initialize(view, *keys, hotkey: nil, sequence: false, **options)
        raise ArgumentError, "kbd takes keys or hotkey:, not both" if hotkey && keys.any?
        raise ArgumentError, "kbd hotkey: can't be a sequence" if hotkey && sequence

        keys = hotkey.to_s.split("+").map { |key| key.length > 1 ? key.downcase.to_sym : key } if hotkey
        raise ArgumentError, "kbd needs at least one key" if keys.empty?

        keys.each do |key|
          if key.is_a?(Symbol) && key != :mod && !KEYS.key?(key)
            raise ArgumentError, "unknown kbd key #{key.inspect} (expected one of #{([ :mod ] + KEYS.keys).inspect})"
          end
        end

        @view = view
        @keys = keys
        @sequence = sequence
        @options = options
      end

      # :mod is the platform's modifier: both glyphs are rendered and the
      # stylesheet shows one, from the server's guess at the platform here and
      # from the browser's own word when hotkey.js has set it on <html>.
      def render
        caps = @keys.map { |key| key == :mod ? [ mod(:apple, :cmd), mod(:other, :ctrl) ] : cap(key) }.flatten
        joiner = tag.span(I18n.t("unmagic.components.kbd.then", default: "then"), class: "UnmagicKbd__joiner")
        classes = view.class_names("UnmagicKbd", { "UnmagicKbd--sequence" => @sequence }, @options[:class])

        tag.kbd(**@options, class: classes, "data-platform": platform) do
          safe_join(@sequence ? caps.flat_map { |c| [ c, joiner ] }[0...-1] : caps)
        end
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def cap(key, **options)
        return tag.kbd(key.to_s, class: "UnmagicKbd__key", **options) unless key.is_a?(Symbol)

        glyph, id = KEYS.fetch(key)
        name = I18n.t("unmagic.components.kbd.#{id}", default: NAMES.fetch(key))

        tag.kbd(title: name, **options, class: view.class_names("UnmagicKbd__key", options[:class])) do
          safe_join [ tag.span(glyph, "aria-hidden": "true"), tag.span(name, class: "UnmagicVisuallyHidden") ]
        end
      end

      def mod(platform, key)
        cap(key, class: "UnmagicKbd__mod UnmagicKbd__mod--#{platform}")
      end

      # Without a request (a mailer, a job) the platform is other.
      def platform
        agent = view.respond_to?(:request) && view.request.respond_to?(:user_agent) ? view.request.user_agent.to_s : ""
        agent.match?(/Mac|iPhone|iPad/) ? "apple" : "other"
      end
    end
  end
end
