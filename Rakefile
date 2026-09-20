# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :browser do
  desc "Compile the component browser's prebuilt stylesheet"
  task :css do
    require "tailwindcss/ruby"

    root = File.expand_path("lib/unmagic/components/browser", __dir__)
    sh Tailwindcss::Ruby.executable, "--minify",
      "-i", File.join(root, "tailwind/browser.css"),
      "-o", File.join(root, "assets/browser.css")
  end

  desc "Write the component browser out as static files: rake browser:export[site,/unmagic-components]"
  task :export, [ :dir, :base ] => :css do |_task, args|
    dir = args[:dir] || "tmp/site"
    base = (args[:base] || "/").to_s

    ENV["RACK_ENV"] ||= "production"
    require "bundler/setup"
    require "logger"
    require "rails"
    require "action_controller/railtie"
    require "action_view/railtie"
    require "turbo-rails"
    require_relative "lib/unmagic/components"

    app = Class.new(Rails::Application) do
      config.load_defaults 8.0
      config.eager_load = false
      config.secret_key_base = "unmagic-components-browser-export"
      config.logger = Logger.new(IO::NULL)
      config.hosts.clear
      config.middleware.delete Rack::Lint
    end
    app.routes.append { mount Unmagic::Components::Browser::Engine => base }
    app.initialize!

    written = Unmagic::Components::Browser.export(app: app, mount: base, dir: dir)
    puts "Wrote #{written.size} files to #{dir} for #{base}"
  end
end

# A released gem always carries a fresh stylesheet.
Rake::Task["build"].enhance([ "browser:css" ])
