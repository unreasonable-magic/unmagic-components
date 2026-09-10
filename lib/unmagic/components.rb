# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/except"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string/output_safety"

require_relative "components/version"
require_relative "components/configuration"
require_relative "components/renderers/empty_state"
require_relative "components/renderers/pagination"
require_relative "components/table_tag"
require_relative "components/table/column"
require_relative "components/table"
require_relative "components/form_builder"
require_relative "components/detail_list/item"
require_relative "components/detail_list"
require_relative "components/action_view_helpers"
# ActionView pulls in a partial Rails namespace, so this checks for the constant it
# actually needs rather than for Rails.
require_relative "components/engine" if defined?(Rails::Engine)

module Unmagic
  module Components
    class << self
      def configure
        yield(configuration) if block_given?
        configuration
      end

      def configuration
        @configuration ||= Configuration.new
      end

      # Drops every customisation, restoring the built-in seams. Intended for
      # tests; an app configures once at boot.
      def reset_configuration!
        @configuration = nil
      end
    end
  end
end
