# frozen_string_literal: true

require "active_model"
require "active_support/core_ext/hash/keys"
require "json_schemer"

module Unmagic
  module Components
    module JSONSchema
    end
  end
end

require_relative "json_schema/property"
require_relative "json_schema/schema"
require_relative "json_schema/instance"
