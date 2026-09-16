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
end

# A released gem always carries a fresh stylesheet.
Rake::Task["build"].enhance([ "browser:css" ])
