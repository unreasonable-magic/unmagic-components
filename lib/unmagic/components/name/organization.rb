# frozen_string_literal: true

module Unmagic
  module Components
    # An organisation's name. Its legal suffix never counts ("Kestrel Pty Ltd" →
    # "Kestrel" → "KE"), capitals inside a word do ("BrightPath" → "BP"), and a mark
    # that leads with a number keeps it ("4K Gardens" → "4K", or "4KG" where an
    # avatar has room). Organisations have no first and last name, so both answer
    # the name without its suffix.
    class Name::Organization < Name
      # Trailing legal suffixes. A multi-word form comes before its one-word tail,
      # so "Pty Ltd" goes whole rather than leaving a stray "Pty".
      SUFFIXES = [
        "pty ltd", "pty limited", "pty", "ltd", "limited", "inc", "incorporated", "llc", "llp", "lp", "plc",
        "gmbh", "ag", "sa", "nv", "bv", "co", "corp", "corporation", "company", "group", "holdings"
      ].freeze

      # Every word but the trailing legal suffixes. A company whose whole name is a
      # suffix ("Limited") keeps it.
      def tokens
        stripped = strip_suffixes(super)
        stripped.presence || super
      end

      def first
        tokens.join(" ").presence
      end
      alias last first

      # Each word's first character, and any capitals after it.
      def significant_chars
        tokens.flat_map { |word| [ word[0], *word[1..].to_s.scan(/[[:upper:]]/) ] }.compact
      end

      # Two characters ("BrightPath" → "BP", "Quiet Harbor Inc" → "QH"). A name
      # with only one ("Kestrel Pty Ltd") takes its first two letters, so a chip
      # never reads as one lonely letter.
      def initials
        chars = significant_chars
        return chars.first(2).join.upcase if chars.size >= 2

        tokens.first.to_s.gsub(/[^[:alpha:]]/, "")[0, 2].to_s.upcase
      end

      # Three characters, only when there's a real third ("4K Gardens" → "4KG",
      # "Guild of Lanterns" → "GOL"). Otherwise the same as #initials.
      def initials_long
        chars = significant_chars
        chars.size >= 3 ? chars.first(3).join.upcase : initials
      end

      private

      # Pops trailing suffixes until none is left, so "... Pty Ltd" loses both, but
      # never takes the last word.
      def strip_suffixes(words)
        words = words.dup

        loop do
          suffix = SUFFIXES.find do |candidate|
            size = candidate.count(" ") + 1
            words.size > size && words.last(size).join(" ").downcase.delete(".,") == candidate
          end
          break unless suffix

          words.pop(suffix.count(" ") + 1)
        end

        words
      end
    end
  end
end
