# frozen_string_literal: true

module ComponentsPreview
  # The components the preview shows, and the examples on each one's page.
  #
  # Each component describes itself in preview/components/<slug>.rb. Its examples
  # are partials in preview/views/examples/<slug>/, rendered live and shown as
  # source, and _thumbnail is its card on the overview. The files are loaded
  # again on every request, so a new example shows up without a restart.
  module Catalog
    Component = Data.define(:slug, :name, :description, :helper, :import, :examples)
    Example = Data.define(:key, :title, :description, :layout)

    # :center sits natural-width content in the middle of the frame; :full lets a
    # table, form or grid use the frame's whole width.
    LAYOUTS = %i[center full].freeze

    class << self
      def component(slug, name:, description:, examples:, helper: nil, import: nil)
        registry[slug.to_s] = Component.new(
          slug: slug.to_s, name: name, description: description, helper: helper, import: import,
          examples: examples.map { |example| build_example(slug, **example) }
        )
      end

      def all = registry.values.sort_by(&:name)

      def find(slug) = registry[slug.to_s]

      def reload!
        @registry = {}
        Dir[File.expand_path("components/*.rb", __dir__)].each { |file| load file }
      end

      private

      def registry = @registry ||= {}

      def build_example(slug, key:, title:, description: nil, layout: :center)
        unless LAYOUTS.include?(layout)
          raise ArgumentError, "unknown layout #{layout.inspect} for #{slug}/#{key} (expected one of #{LAYOUTS.inspect})"
        end

        Example.new(key: key.to_s, title: title, description: description, layout: layout)
      end
    end
  end
end
