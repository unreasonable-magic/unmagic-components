# frozen_string_literal: true

module ComponentsPreview
  # A canned assistant reply for the streaming examples, and the growing renders a
  # server would broadcast while writing it. A host renders its own Markdown; the
  # preview has none, so the reply is kept as blocks of HTML and a snapshot is the
  # first n words of it, cut the way a half-written reply would be.
  module Reply
    BLOCKS = [
      [ :p, "Three candidates haven't replied since the invitations went out on Monday." ],
      [ :ul, [ "Ana Silva opened hers twice but hasn't answered.", "Grace Okafor hasn't opened hers.",
               "Tom Reyes's bounced, so the address is probably wrong." ] ],
      [ :p, "I'd send Ana a short nudge today, check Tom's address against his CV, and leave Grace until Thursday." ],
      [ :pre, "invitations.unanswered.where(sent_at: ..3.days.ago)" ],
      [ :p, "Want me to draft the nudge for Ana?" ]
    ].freeze

    class << self
      include ERB::Util

      def words = BLOCKS.sum { |_, content| Array(content).sum { |text| text.split.size } }

      def html(limit = words)
        remaining = limit
        BLOCKS.filter_map do |tag, content|
          next if remaining <= 0

          case tag
          when :ul
            items = content.filter_map do |text|
              next if remaining <= 0

              "<li>#{take(text, remaining).tap { remaining -= text.split.size }}</li>"
            end
            "<ul>#{items.join}</ul>"
          when :pre
            text = take(content, remaining)
            remaining -= content.split.size
            "<pre><code>#{text}</code></pre>"
          else
            text = take(content, remaining)
            remaining -= content.split.size
            "<#{tag}>#{text}</#{tag}>"
          end
        end.join.html_safe # rubocop:disable Rails/OutputSafety -- the preview's own constant copy, escaped word by word
      end

      # Uneven bursts, as a model produces them.
      def snapshots
        sizes = [ 3, 1, 6, 2, 9, 4, 1, 7, 12, 3, 5, 2, 8 ]
        limit = 0
        result = []
        sizes.cycle.each do |size|
          limit = [ limit + size, words ].min
          result << html(limit)
          break if limit == words
        end
        result
      end

      private

      def take(text, count)
        html_escape(text.split.first([ count, 0 ].max).join(" "))
      end
    end
  end
end
