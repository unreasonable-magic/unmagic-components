# frozen_string_literal: true

require "active_model"
require "active_support/core_ext/hash/keys"
require "json_schemer"

# Also load the schema-specific defaults when used without a Rails engine.
I18n.load_path |= [ File.expand_path("../../../config/locales/en.yml", __dir__) ]

module Unmagic
  module Components
    module JSONSchema
    end
  end
end

require_relative "json_schema/property"
require_relative "json_schema/schema"
require_relative "json_schema/instance"
