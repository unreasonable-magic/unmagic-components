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

  # The preview server (config.ru, bin/dev). Propshaft is here so the preview
  # serves the stylesheet the same way a host app does, through
  # stylesheet_link_tag "unmagic/components".
  gem "puma"
  gem "rackup"
  gem "propshaft"

  # The preview loads the gem's JavaScript through importmap-rails, exactly as a
  # host does — the engine's pins resolve the component elements by name.
  gem "importmap-rails"

  # json 3 takes JSON.parse options as keywords only, and ActiveSupport 8.1.3.1
  # still passes a positional hash, so every request carrying a session cookie
  # raises ArgumentError in the preview.
  gem "json", "< 3"
end
