# frozen_string_literal: true

module Unmagic
  module Components
    # A stretch of time as somebody would say it: 640ms, 2s, 3m 5s, 1h 4m 2s. Prose
    # about a wait rather than a clock, so the larger units are left off until they
    # are needed. Anything under a second is milliseconds, since most tool calls
    # answer in a fraction of one and "0s" says nothing about which fraction.
    #
    # <unmagic-elapsed> writes the same words while a clock is running (elapsed.js),
    # so a reading doesn't change shape the moment it settles. Change both together.
    module Duration
      def self.format(seconds)
        return if seconds.nil?

        if seconds.positive? && seconds < 1
          return I18n.t("unmagic.components.elapsed.milliseconds", count: (seconds * 1000).round, default: "%{count}ms")
        end

        whole = seconds.round
        hours, remainder = whole.divmod(3600)
        minutes, secs = remainder.divmod(60)

        if whole < 60
          I18n.t("unmagic.components.elapsed.seconds", count: whole, default: "%{count}s")
        elsif whole < 3600
          I18n.t("unmagic.components.elapsed.minutes", minutes: minutes, seconds: secs, default: "%{minutes}m %{seconds}s")
        else
          I18n.t("unmagic.components.elapsed.hours", hours: hours, minutes: minutes, seconds: secs,
            default: "%{hours}h %{minutes}m %{seconds}s")
        end
      end
    end
  end
end
