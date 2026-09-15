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
require "importmap-rails"

require_relative "lib/unmagic/components"
require_relative "preview/thing"
require_relative "preview/pager"
require_relative "preview/profile"

module ComponentsPreview
  class Application < Rails::Application
    config.load_defaults 8.0

    config.eager_load = false
    config.consider_all_requests_local = true
    config.secret_key_base = "unmagic-components-preview"
    config.logger = Logger.new($stdout)
    config.middleware.delete Rack::Lint

    # The Tailwind build bin/dev compiles from preview/tailwind/application.css,
    # which imports the gem's engine.css as a host's build would.
    config.assets.paths << File.expand_path("preview/builds", __dir__)

    # The gem's own pins arrive through the engine, as in a host. Turbo's pin is the
    # one a host's config/importmap.rb would carry.
    config.importmap.paths << File.expand_path("preview/importmap.rb", __dir__)

    routes.append do
      root to: "preview#index"
      get "/deferred", to: "preview#deferred"

      get "/dialogs", to: "preview#dialogs"
      get "/dialogs/profile", to: "preview#edit_profile"
      patch "/dialogs/profile", to: "preview#update_profile"
      delete "/dialogs/profile", to: "preview#destroy_profile"
      get "/dialogs/slow", to: "preview#slow_dialog"
      get "/dialogs/forbidden", to: "preview#forbidden_dialog"

      get "/primitives", to: "preview#primitives"
      get "/elements", to: "preview#elements"
      get "/skeletons", to: "preview#skeletons"
      get "/forms", to: "preview#forms"

      get "/toasts", to: "preview#toasts"
      post "/toasts/flash", to: "preview#flash_toast"
      post "/toasts/stream", to: "preview#stream_toast"
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
