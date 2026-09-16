# frozen_string_literal: true

require_relative "action_view_helpers"

module Unmagic
  module Components
    class Engine < ::Rails::Engine
      isolate_namespace Unmagic::Components

      # Both hooks, because a helper test never touches ActionView::Base. The :action_view hook
      # mixes into Base, which is what a template renders through — but ActionView::TestCase builds
      # its own view class and calls the helper under test on the test case itself. So a host helper
      # that composes one of these (badge, button_classes) works in the app and raises NoMethodError
      # in its own spec, which is a confusing place to send someone.
      initializer "unmagic_components.helpers" do
        ActiveSupport.on_load(:action_view) do
          include Unmagic::Components::ActionViewHelpers
        end

        ActiveSupport.on_load(:action_view_test_case) do
          include Unmagic::Components::ActionViewHelpers
        end
      end

      # turbo_stream.toast. turbo-rails runs this hook when its tag builder loads, so
      # an app without Turbo never sees it.
      initializer "unmagic_components.turbo_streams" do
        ActiveSupport.on_load(:turbo_streams_tag_builder) do
          include Unmagic::Components::TurboStreamActions
        end
      end

      # The components' JavaScript, served through the asset pipeline. There is no
      # stylesheet to serve: the styles are Tailwind source in
      # app/assets/tailwind/unmagic_components/engine.css, which tailwindcss-rails
      # finds by this engine's name and the host's own Tailwind build compiles.
      initializer "unmagic_components.assets" do |app|
        next unless app.config.respond_to?(:assets)

        app.config.assets.paths << Engine.root.join("app/assets/javascripts")
      end

      # The components' JavaScript: custom elements and the `upsert` Turbo Stream
      # action. Pinned rather than served so the host imports each by name
      # ("unmagic/components", or "unmagic/components/modal"). importmap-rails is
      # optional; an app without it never sees the pins and wires the files up its
      # own way.
      initializer "unmagic_components.importmap", before: "importmap" do |app|
        next unless app.config.respond_to?(:importmap)

        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << Engine.root.join("app/assets/javascripts")
      end
    end
  end
end
