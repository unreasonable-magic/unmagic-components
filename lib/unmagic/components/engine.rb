# frozen_string_literal: true

require_relative "action_view_helpers"

module Unmagic
  module Components
    class Engine < ::Rails::Engine
      isolate_namespace Unmagic::Components

      initializer "unmagic_components.helpers" do
        ActiveSupport.on_load(:action_view) do
          include Unmagic::Components::ActionViewHelpers
        end
      end

      # The components' stylesheet is a plain CSS file, deliberately not part of any
      # Tailwind build: Tailwind only generates classes it can see, and it does not
      # scan installed gems. Serving it through the asset pipeline keeps the gem's
      # look self-contained and themeable through --unmagic-* custom properties.
      initializer "unmagic_components.assets" do |app|
        next unless app.config.respond_to?(:assets)

        app.config.assets.paths << Engine.root.join("app/assets/stylesheets")
        app.config.assets.paths << Engine.root.join("app/assets/javascripts")
      end

      # The one piece of JavaScript here: the `upsert` Turbo Stream action a live
      # table's broadcasts use. Pinned rather than served so the host imports it by
      # name; importmap-rails is optional, and an app without it simply never sees
      # the pin (and cannot broadcast into a table).
      initializer "unmagic_components.importmap", before: "importmap" do |app|
        next unless app.config.respond_to?(:importmap)

        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << Engine.root.join("app/assets/javascripts")
      end
    end
  end
end
