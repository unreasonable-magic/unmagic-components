# frozen_string_literal: true

# A preview server for the components, so they can be looked at without an
# application around them: bin/dev, then http://localhost:5701.
#
# Deliberately a whole Rails app in one file. The components are ActionView
# helpers that read params and the request, so a preview needs a real view
# context — but nothing here belongs in a checked-in dummy app.

ENV["RACK_ENV"] ||= "development"

require "bundler/setup"
require "logger"
require "rails"
require "active_model"
require "action_controller/railtie"
require "propshaft"
require "action_view/railtie"
require "turbo-rails"

require_relative "lib/unmagic/components"
require_relative "preview/thing"
require_relative "preview/pager"

module ComponentsPreview
  class Application < Rails::Application
    config.load_defaults 8.0

    config.eager_load = false
    config.consider_all_requests_local = true
    config.secret_key_base = "unmagic-components-preview"
    config.logger = Logger.new($stdout)
    config.middleware.delete Rack::Lint

    config.assets.paths << Unmagic::Components::Engine.root.join("app/assets/stylesheets")

    routes.append do
      root to: "preview#index"
      get "/deferred", to: "preview#deferred"
    end
  end
end

# The pager is a stand-in rather than real Pagy: the preview only needs
# something that answers previous/next/page_url.
Unmagic::Components.configure do |config|
  config.pagy_for = ->(_view, _collection) { ComponentsPreview::Pager.new(1, 3) }
end

require_relative "preview/preview_controller"

ComponentsPreview::Application.initialize!
run ComponentsPreview::Application
