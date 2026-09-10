# frozen_string_literal: true

require_relative "lib/unmagic/components/version"

Gem::Specification.new do |spec|
  spec.name        = "unmagic-components"
  spec.version     = Unmagic::Components::VERSION
  spec.authors     = [ "Keith Pitt" ]
  spec.email       = [ "keith@unreasonable-magic.com" ]
  spec.summary     = "Declarative table, detail-list and form builders for Rails views"
  spec.description = "Server-rendered view builders in the spirit of form_for. table_for " \
                     "for index tables — sortable headers, deferred turbo-frame loading with a " \
                     "matching skeleton, empty states, pagination, and rows a Turbo Stream can " \
                     "keep up to date. detail_list for description lists, and a form builder for " \
                     "the chrome around a control. Plain Rails helpers, themed through CSS " \
                     "custom properties."
  spec.homepage    = "https://github.com/unreasonable-magic/unmagic-components"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # config/importmap.rb has to ship: the engine points importmap-rails at it so a
  # host can import the upsert action by name.
  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "actionview", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
end
