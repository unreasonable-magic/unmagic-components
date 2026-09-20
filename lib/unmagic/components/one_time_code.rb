# frozen_string_literal: true

module Unmagic
  module Components
    # One input for a code sent by SMS or email, drawn as a row of boxes once
    # script arrives. See FormBuilder#one_time_code_field.
    module OneTimeCode
      CHARSETS = { numeric: { inputmode: "numeric", pattern: "[0-9]{%d}" },
                   alphanumeric: { inputmode: "text", pattern: "[A-Za-z0-9]{%d}" } }.freeze

      # The attributes the single input needs: the right keyboard, the platform's
      # code suggestion, and a pattern the length long.
      def self.input_options(options, length:, charset:)
        raise ArgumentError, "one_time_code_field length: must be 4 to 10" unless (4..10).cover?(length)
        raise ArgumentError, "unknown one_time_code charset #{charset.inspect} (expected one of #{CHARSETS.keys.inspect})" unless CHARSETS.key?(charset)

        set = CHARSETS[charset]
        { type: "text", inputmode: set[:inputmode], pattern: format(set[:pattern], length), maxlength: length,
          autocomplete: "one-time-code", spellcheck: "false", autocapitalize: "off", value: nil }.merge(options)
      end

      def self.wrap(view, input, length:, charset:, submit:)
        view.content_tag("unmagic-one-time-code", input, class: "UnmagicOneTimeCode", length: length, charset: charset,
          submit: (submit ? "" : nil))
      end
    end
  end
end
