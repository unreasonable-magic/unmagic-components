# frozen_string_literal: true

# The component browser, run on its own: bin/dev, then http://localhost:5701.
#
# This is a host app in one file that mounts Unmagic::Components::Browser::Engine and
# does nothing else, so what runs here is exactly what a host that mounts the
# browser gets. It has no asset pipeline and no importmap: the browser serves its
# own stylesheet and JavaScript.

ENV["RACK_ENV"] ||= "development"

require "bundler/setup"
require "logger"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "turbo-rails"

require_relative "lib/unmagic/components"

module ComponentsBrowser
  class Application < Rails::Application
    config.load_defaults 8.0

    config.eager_load = false
    config.consider_all_requests_local = true
    config.secret_key_base = "unmagic-components-browser"
    config.logger = Logger.new($stdout)
    config.middleware.delete Rack::Lint
    config.hosts.clear

    routes.append do
      mount Unmagic::Components::Browser::Engine => "/"
    end
  end
end

ComponentsBrowser::Application.initialize!
run ComponentsBrowser::Application
