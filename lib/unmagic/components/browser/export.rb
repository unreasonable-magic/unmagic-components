# frozen_string_literal: true

require "fileutils"
require "rack/mock"

module Unmagic
  module Components
    module Browser
      # Writes the browser out as static files, for hosting where nothing runs:
      # GitHub Pages, a pull request's preview. Every page the browser has is
      # requested through the Rack app it is mounted in and written as
      # <path>/index.html under the directory, with the stylesheet, the
      # components' JavaScript and Turbo copied beside them, so the links and
      # asset URLs the pages already carry keep working.
      #
      #   Unmagic::Components::Browser::Export.new(app: Rails.application, mount: "/unmagic/components", dir: "site").run
      #
      # The mount is the path the engine is mounted at in the app, which is also
      # the path the site will be served under (a project site on GitHub Pages
      # lives under /<repo>/, a preview under /<repo>/pr-42/). Everything under
      # the mount is written relative to the directory.
      #
      # Examples that talk to a server (a form that saves, a search) are marked
      # server: true in the catalog and say so on the static page; the profile
      # dialog's form is written out as the frame the modal fetches, so that one
      # still opens. rake browser:export[dir,base] does all this from the gem.
      class Export
        PAGES = %w[/ /installation /theming /components /blocks].freeze

        attr_reader :dir, :mount, :written

        def initialize(app:, mount:, dir:)
          @app = app
          @mount = mount.to_s.chomp("/")
          @dir = Pathname(dir)
          @written = []
        end

        def run
          Browser.static = true
          FileUtils.mkdir_p(dir)
          pages.each { |path| write(path, fetch(path)) }
          write("/dialogs/profile", fetch("/dialogs/profile", "HTTP_TURBO_FRAME" => Components.configuration.modal_frame_id))
          write_file("404.html", fetch("/components/nope", status: 404))
          copy_assets
          written
        ensure
          Browser.static = false
        end

        # The pages: the getting-started ones, the gallery, and one per component,
        # block and guide.
        def pages
          PAGES + Catalog.all.map { |component| "/components/#{component.slug}" } +
            BlockCatalog.all.flat_map { |block| [ "/blocks/#{block.slug}", "/blocks/#{block.slug}/preview" ] } +
            GuideCatalog.all.map { |guide| "/guides/#{guide.slug}" }
        end

        private

        def fetch(path, status: 200, **env)
          response = Rack::MockRequest.new(@app).get("#{mount}#{path}", "HTTP_HOST" => "localhost", **env)
          unless response.status == status
            raise "#{mount}#{path} answered #{response.status}: #{response.body[0, 300]}"
          end

          response.body
        end

        def write(path, body)
          file = path == "/" ? "index.html" : File.join(path.delete_prefix("/"), "index.html")
          write_file(file, body)
        end

        def write_file(file, body)
          target = dir.join(file)
          FileUtils.mkdir_p(target.dirname)
          File.write(target, body)
          written << file
        end

        # The same files the browser serves under assets/<kind>/, so the URLs in
        # the pages resolve. The ?v= stamp on those URLs is a query a static host
        # ignores.
        def copy_assets
          Browser.asset_roots.each do |kind, root|
            files = case kind
            when "stylesheets" then [ "browser.css" ]
            when "browser" then [ "browser.js" ]
            when "javascripts" then Dir[root.join("unmagic/components{,/**/*}.js")].map { |f| Pathname(f).relative_path_from(root).to_s }
            when "turbo" then [ "turbo.min.js" ]
            end

            files.each do |name|
              source = root.join(name)
              next unless File.exist?(source)

              target = dir.join("assets", kind, name)
              FileUtils.mkdir_p(target.dirname)
              FileUtils.cp(source, target)
              written << File.join("assets", kind, name)
            end
          end
        end
      end
    end
  end
end
