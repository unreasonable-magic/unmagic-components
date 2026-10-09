# frozen_string_literal: true

require "active_support/core_ext/object/blank"

module Unmagic
  module Components
    # A name that knows its own parts: `name.first`, `name.last`, `name.initials`.
    # It is a String, so it goes anywhere a name already goes (views, sorting, JSON,
    # comparisons) and adds the parsing on top. An avatar asks a name for its
    # initials, so passing one of these, or any object that answers #initials, is
    # how a host changes what the avatar shows.
    #
    # The base class reads every word plainly: the first and last words, and their
    # first letters as initials ("Ada Lovelace" → "AL", "Plato" → "P"). Name::Person
    # and Name::Organization know the shapes real names come in.
    class Name < String
      # Surrounding whitespace is dropped, and runs of it inside are kept as typed:
      # the name reads back the way it was entered, trimmed.
      def initialize(raw = "")
        super(raw.to_s.strip)
      end

      # The words that count towards the name. Subclasses narrow this: a person's
      # skip emoji, an organisation's skip legal suffixes.
      def tokens
        split
      end

      def first
        tokens.first
      end

      def last
        tokens.last if tokens.size > 1
      end

      def initials
        [ tokens.first, (tokens.last if tokens.size > 1) ].compact.map { |word| word[0] }.join.upcase
      end

      # A longer (about three character) mark for an avatar with room for it. The
      # same as #initials unless a subclass has a real third character to show.
      def initials_long
        initials
      end
    end
  end
end
