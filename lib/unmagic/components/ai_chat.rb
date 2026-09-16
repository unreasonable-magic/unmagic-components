# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # The components for rendering an agent's work: a transcript of turns, the
    # tools it reached for, the plan it is following, the questions it stopped to
    # ask, and the box a person answers in. ai_chat is the root; the rest are
    # ai_chat_* helpers. See docs/components/ai_chat.
    module AIChat
      # Validates an enumerated option the way every component in the gem does.
      def self.validate!(component, option, value, allowed)
        return if allowed.include?(value)

        raise ArgumentError, "unknown #{component} #{option} #{value.inspect} (expected one of #{allowed.inspect})"
      end

      # A word the gem prints, under the family's I18n scope.
      def self.t(key, **options)
        I18n.t("unmagic.components.ai_chat.#{key}", **options)
      end

      # A base for element ids that must reference each other when the caller
      # gave none.
      def self.random_id(name)
        "unmagic_ai_chat_#{name}_#{SecureRandom.hex(4)}"
      end
    end
  end
end
