# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # Inherits ActionController::Base rather than the host's ApplicationController,
      # so the host's authentication, layout and callbacks stay out. Access is the
      # host's to decide where it mounts the browser.
      class ApplicationController < ActionController::Base
        include Unmagic::Components::DialogResponder

        THEMES = %w[light dark].freeze

        # Everything the browser keeps in the host's session sits under keys with
        # this prefix, so none collides with the host's own.
        SESSION_PREFIX = "unmagic_components_browser"

        # A frame request gets no layout, as turbo-rails arranges for an app's
        # default one; naming a layout here would otherwise override that.
        layout -> { turbo_frame_request? ? false : "unmagic/components/browser/application" }

        helper Unmagic::Components::Browser::ApplicationHelper
        helper_method :dark_theme?

        before_action :require_turbo, :remember_theme, :load_catalog

        private

        # Checked per request rather than at load, because a host that eager loads
        # the browser's classes without mounting it may not have Turbo at all.
        def require_turbo
          return if defined?(::Turbo::Engine)

          raise "Unmagic::Components::Browser needs turbo-rails: add it to your Gemfile"
        end

        # ?theme=dark or ?theme=light switches the browser and sticks for the
        # session, so links and redirects don't each have to carry it.
        def remember_theme
          browser_session[:theme] = params[:theme] if THEMES.include?(params[:theme])
        end

        def dark_theme? = browser_session[:theme] == "dark"

        def load_catalog
          Catalog.reload! if Rails.env.development?
          @components = Catalog.all
          @component_groups = Catalog.grouped
        end

        def browser_session = BrowserSession.new(session)

        def stored_profile
          Profile.new(browser_session[:profile] || { name: "Ada Lovelace", role: "Engineer" })
        end

        def board_store = @board_store ||= BoardStore.new(browser_session)

        # The host's session, seen through prefixed keys.
        class BrowserSession
          def initialize(session)
            @session = session
          end

          def [](key) = @session[name(key)]

          def []=(key, value)
            @session[name(key)] = value
          end

          def delete(key) = @session.delete(name(key))

          private

          def name(key) = "#{SESSION_PREFIX}_#{key}"
        end
      end
    end
  end
end
