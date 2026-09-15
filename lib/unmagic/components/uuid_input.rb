# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A hidden field holding a client-known UUIDv7. See FormBuilder#uuid_field.
    class UuidInput
      def initialize(view, name, **options)
        @view = view
        @name = name
        @options = options
      end

      # The server renders an id of its own so the form still submits one without
      # the script; the element replaces it as it upgrades, and again on each reset.
      def render
        @view.content_tag("unmagic-uuid-input", name: @name, **@options) do
          @view.hidden_field_tag(@name, SecureRandom.uuid_v7, id: nil, autocomplete: "off")
        end
      end
    end
  end
end
