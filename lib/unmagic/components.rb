# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/except"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string/output_safety"
require "active_support/isolated_execution_state"

require_relative "components/version"
require_relative "components/configuration"
require_relative "components/control"
require_relative "components/renderers/empty_state"
require_relative "components/renderers/pagination"
require_relative "components/pagination"
require_relative "components/table_tag"
require_relative "components/table/column"
require_relative "components/table"
require_relative "components/password"
require_relative "components/one_time_code"
require_relative "components/input_group"
require_relative "components/toggle"
require_relative "components/toggle_group"
require_relative "components/form_builder"
require_relative "components/skeleton"
require_relative "components/detail_list/item"
require_relative "components/detail_list"
require_relative "components/icons"
require_relative "components/button"
require_relative "components/spinner"
require_relative "components/button_tag"
require_relative "components/button_group"
require_relative "components/separator"
require_relative "components/progress"
require_relative "components/dialog"
require_relative "components/modal"
require_relative "components/confirm_template"
require_relative "components/dialog_responder"
require_relative "components/toast"
require_relative "components/toasts"
require_relative "components/turbo_stream_actions"
require_relative "components/badge"
require_relative "components/callout"
require_relative "components/card"
require_relative "components/breadcrumbs"
require_relative "components/tree_view"
require_relative "components/page_header"
require_relative "components/section"
require_relative "components/item"
require_relative "components/chart"
require_relative "components/kbd"
require_relative "components/local_time"
require_relative "components/tooltip"
require_relative "components/menu"
require_relative "components/popover"
require_relative "components/disclosure"
require_relative "components/scroll_area"
require_relative "components/sidebar"
require_relative "components/navbar"
require_relative "components/combobox"
require_relative "components/command_palette"
require_relative "components/tabs"
require_relative "components/panel"
require_relative "components/copy_button"
require_relative "components/highlight"
require_relative "components/code_view"
require_relative "components/autogrow"
require_relative "components/uuid_input"
require_relative "components/duration"
require_relative "components/elapsed"
require_relative "components/streaming_markdown"
require_relative "components/avatar"
require_relative "components/sortable"
require_relative "components/board"
require_relative "components/ai_chat"
require_relative "components/ai_chat/payload"
require_relative "components/ai_chat/reasoning"
require_relative "components/ai_chat/message"
require_relative "components/ai_chat/transcript"
require_relative "components/ai_chat/tool_call"
require_relative "components/ai_chat/failure"
require_relative "components/ai_chat/section"
require_relative "components/ai_chat/plan"
require_relative "components/ai_chat/workspace"
require_relative "components/ai_chat/composer"
require_relative "components/ai_chat/request"
require_relative "components/ai_chat/permission"
require_relative "components/ai_chat/proposal"
require_relative "components/ai_chat/citation"
require_relative "components/ai_chat/welcome"
require_relative "components/ai_chat/attachments"
require_relative "components/ai_chat/slash_menu"
require_relative "components/ai_chat/action_bar"
require_relative "components/ai_chat/branch_picker"
require_relative "components/image_zoom"
require_relative "components/image_crop"
require_relative "components/image_color_picker"
require_relative "components/action_view_helpers"
# ActionView pulls in a partial Rails namespace, so this checks for the constant it
# actually needs rather than for Rails.
if defined?(Rails::Engine)
  require_relative "components/engine"
  require_relative "components/browser"
end

module Unmagic
  module Components
    class << self
      def configure
        yield(app_configuration) if block_given?
        app_configuration
      end

      # The app's configuration, unless the current request or job is inside
      # with_default_configuration.
      def configuration
        ActiveSupport::IsolatedExecutionState[:unmagic_components_configuration] || app_configuration
      end

      # Runs the block with the built-in seams, whatever the app configured. The
      # browser renders through this, so none of a host's code (its partials, and
      # the helpers they call) runs inside it. The override is per thread or fiber,
      # so the app's own requests running alongside keep the app's configuration.
      def with_default_configuration
        previous = ActiveSupport::IsolatedExecutionState[:unmagic_components_configuration]
        ActiveSupport::IsolatedExecutionState[:unmagic_components_configuration] = Configuration.new
        yield
      ensure
        ActiveSupport::IsolatedExecutionState[:unmagic_components_configuration] = previous
      end

      # Drops every customisation, restoring the built-in seams. Intended for
      # tests; an app configures once at boot.
      def reset_configuration!
        @app_configuration = nil
      end

      private

      def app_configuration
        @app_configuration ||= Configuration.new
      end
    end
  end
end
