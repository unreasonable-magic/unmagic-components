# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rake"
  gem "rspec"
  gem "rubocop-rails-omakase", require: false

  # Spec fixtures: Active Model gives the plain rows a model_name so dom_id has
  # something to work with, without dragging in a database.
  gem "activemodel"
  gem "nokogiri"

  # Turbo is an optional integration the gem detects at runtime; the deferred
  # table specs need turbo_frame_tag to be real.
  gem "turbo-rails"

  # Runs the component browser on its own (config.ru, bin/dev).
  gem "puma"
  gem "rackup"

  # The Tailwind CLI, which a host gets through tailwindcss-rails. rake
  # browser:css compiles the browser's prebuilt stylesheet with it, and a spec
  # compiles engine.css so a broken @apply fails here rather than in someone's app.
  gem "tailwindcss-ruby"

  # json 3 takes JSON.parse options as keywords only, and ActiveSupport 8.1.3.1
  # still passes a positional hash, so every request carrying a session cookie
  # raises ArgumentError in the browser.
  gem "json", "< 3"
end
