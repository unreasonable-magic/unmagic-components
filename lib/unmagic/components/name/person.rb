# frozen_string_literal: true

module Unmagic
  module Components
    # A person's name. Particles bind to the surname ("Ludwig van Beethoven" → last
    # "van Beethoven", initials "LB"), a mononym is its own first name ("Prince" →
    # "PR"), and middle names are ignored. Pragmatic, not locale-perfect.
    class Name::Person < Name
      # Lowercased surname particles. A trailing comma ("van," from a parsed list)
      # is stripped before comparing.
      PARTICLES = %w[
        van von der den de del della di da dos das du la le el bin ibn al af zu ter ten
      ].freeze

      # The words that carry a letter, so a leading emoji or stray punctuation
      # ("👋 Jane Smith") isn't taken for a name. A name of nothing but symbols
      # falls back to its raw words, so nothing here comes back empty.
      def tokens
        worded = super.select { |token| token.match?(/[[:alpha:]]/) }
        worded.presence || super
      end

      # The surname, with any particles before it ("van der Berg"). A hyphenated
      # surname is one word. A mononym has none.
      def last
        return if tokens.size <= 1

        start = surname_index
        start -= 1 while start > 1 && particle?(tokens[start - 1])
        tokens[start..].join(" ")
      end

      # The name as a byline signs it: "Leilani W.". A mononym is just itself.
      def short
        if (initial = last&.gsub(/[^[:alpha:]]/, "")&.[](0))
          "#{first} #{initial.upcase}."
        else
          first
        end
      end

      # The first name's letter and the surname proper's, skipping particles
      # ("Ludwig van Beethoven" → "LB"). A mononym gives its first two letters
      # ("Prince" → "PR").
      def initials
        if tokens.size <= 1
          tokens.first.to_s.gsub(/[^[:alpha:]]/, "")[0, 2].to_s.upcase
        else
          "#{tokens.first[0]}#{tokens[surname_index][0]}".upcase
        end
      end

      private

      def surname_index
        tokens.rindex { |token| !particle?(token) } || (tokens.size - 1)
      end

      def particle?(token)
        PARTICLES.include?(token.downcase.delete_suffix(","))
      end
    end
  end
end
