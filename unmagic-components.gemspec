# frozen_string_literal: true

require_relative "lib/unmagic/components/version"

Gem::Specification.new do |spec|
  spec.name        = "unmagic-components"
  spec.version     = Unmagic::Components::VERSION
  spec.authors     = [ "Keith Pitt" ]
  spec.email       = [ "keith@unreasonable-magic.com" ]
  spec.summary     = "Server-rendered UI components for Rails: tables, forms, dialogs, toasts and more"
  spec.description = "UI components for Rails views in the spirit of form_for. Builders for index " \
                     "tables (sortable, deferred, kept live by Turbo Streams), detail lists, forms, " \
                     "cards, page headers and loading skeletons; a Turbo Frame modal, a confirm " \
                     "dialog and flash toasts; menus, tabs, tooltips, local times, copy buttons, " \
                     "autogrowing textareas and UUID inputs as self-registering custom elements. " \
                     "Plain helpers and CSS themed through custom properties, with no Tailwind or " \
                     "Stimulus required."
  spec.homepage    = "https://github.com/unreasonable-magic/unmagic-components"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # config/importmap.rb has to ship: the engine points importmap-rails at it so a
  # host can import the upsert action by name.
  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.required_ruby_version = ">= 3.3"

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "actionview", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
end
