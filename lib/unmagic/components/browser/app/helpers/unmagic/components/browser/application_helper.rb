# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      module ApplicationHelper
        EXAMPLES = "unmagic/components/browser/examples"

        # The browser's own importmap: the names config/importmap.rb pins for a
        # host, and Turbo's, resolved to the files the browser serves itself.
        def browser_importmap_tags
          javascripts = Browser.asset_roots.fetch("javascripts")
          imports = {
            "@hotwired/turbo-rails" => browser_asset_path("turbo", "turbo.min.js"),
            "unmagic/components" => browser_asset_path("javascripts", "unmagic/components.js")
          }
          Dir[javascripts.join("unmagic/components/**/*.js")].sort.each do |file|
            name = Pathname(file).relative_path_from(javascripts).to_s
            imports[name.delete_suffix(".js")] = browser_asset_path("javascripts", name)
          end

          safe_join [
            tag.script({ imports: imports }.to_json.html_safe, type: "importmap", nonce: content_security_policy_nonce), # rubocop:disable Rails/OutputSafety -- JSON of our own paths
            tag.script('import "unmagic/components"'.html_safe, type: "module", nonce: content_security_policy_nonce) # rubocop:disable Rails/OutputSafety -- a constant
          ], "\n"
        end

        def browser_stylesheet_tag
          tag.link rel: "stylesheet", href: browser_asset_path("stylesheets", "browser.css")
        end

        # A file the browser serves, stamped so a changed file is fetched afresh
        # and an unchanged one comes from cache. The modification time covers
        # editing in development; the version (turbo-rails' own, for Turbo)
        # covers an upgrade, because gem packaging gives every file the same time.
        def browser_asset_path(kind, name)
          file = Browser.asset_roots.fetch(kind).join(name)
          mtime = File.exist?(file) ? File.mtime(file).to_i : 0
          version = (Gem.loaded_specs["turbo-rails"]&.version if kind == "turbo") || Components::VERSION
          "#{root_path}assets/#{kind}/#{name}?v=#{version}-#{mtime}"
        end

        def example_partial(component, key) = "#{EXAMPLES}/#{component.slug}/#{key}"

        # What the Code tab shows: the example's partial, exactly as it's rendered.
        def example_source(component, example)
          Browser.root.join("app/views", EXAMPLES, component.slug, "_#{example.key}.html.erb").read.rstrip
        end
      end
    end
  end
end
