# frozen_string_literal: true

module Unmagic
  module Components
    # The components for showing people talking to each other, or to a machine:
    # a thread of messages, with who said it, when, what came with it, how
    # others reacted, and what can be done to it. One family draws an
    # iMessage-style chat, a Slack-style thread, an email back-and-forth and an
    # AI chat (whose ai_chat_message is a subclass of Message). See
    # docs/components/messaging.
    module Messaging
      # Validates an enumerated option the way every component in the gem does.
      def self.validate!(component, option, value, allowed)
        return if allowed.include?(value)

        raise ArgumentError, "unknown #{component} #{option} #{value.inspect} (expected one of #{allowed.inspect})"
      end

      # A word the gem prints, under the family's I18n scope.
      def self.t(key, **options)
        I18n.t("unmagic.components.message.#{key}", **options)
      end

      # An avatar from what a caller wrote: true (the author's initials), a name,
      # or a Hash of avatar options. Hidden from assistive tech when the author's
      # name is written beside it, since then it would only repeat the name.
      def self.avatar(view, spec, author:, size:)
        name, options = case spec
        when true then [ author, {} ]
        when Hash then [ spec[:name] || author, spec.except(:name) ]
        else [ spec, {} ]
        end

        Avatar.new(view, name, **options, size: size, "aria-hidden": ("true" if author.present?)).render
      end
    end
  end
end
