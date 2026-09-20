# frozen_string_literal: true

module Unmagic
  module Components
    # A browser for the components, which a host mounts to look through every
    # component, its examples and their source inside its own app:
    #
    #   mount Unmagic::Components::Browser::Engine => "/unmagic/components" if Rails.env.development?
    #
    # It is self-contained. Its stylesheet is prebuilt with the gem's default theme
    # (rake browser:css), and it serves that, the components' JavaScript and Turbo
    # itself, under its own importmap, so a host changes none of its own CSS or JS.
    # turbo-rails has to be in the bundle.
    module Browser
      # Its root is this directory's browser/, not the gem root: the main engine's
      # root is the gem root, so anything in the top-level app/ is autoloaded into
      # every host.
      class Engine < ::Rails::Engine
        isolate_namespace Unmagic::Components::Browser

        config.root = File.expand_path("browser", __dir__)
      end

      class << self
        def root = Engine.root

        # True while Export writes the pages out as static files, so an example
        # that talks to a server can say it won't here.
        attr_accessor :static

        def static? = static == true

        def export(app:, mount:, dir:) = Export.new(app: app, mount: mount, dir: dir).run

        # What the browser serves under <mount>/assets/<kind>/, by kind.
        def asset_roots
          roots = {
            "stylesheets" => root.join("assets"),
            "javascripts" => Components::Engine.root.join("app/assets/javascripts")
          }
          roots["turbo"] = ::Turbo::Engine.root.join("app/assets/javascripts") if defined?(::Turbo::Engine)
          roots
        end
      end
    end
  end
end

require_relative "browser/export"
